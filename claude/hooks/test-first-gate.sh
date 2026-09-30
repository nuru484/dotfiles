#!/usr/bin/env bash
# PreToolUse gate on `git commit`: a commit that adds a use case or a screen
# component is refused unless a test in the index names it. Test-first
# slipped repeatedly on large builds while the rule lived only in writing;
# this makes a new behaviour file without its test impossible to commit.
set -euo pipefail

input=$(cat)
[ "$(jq -r '.tool_name // ""' <<<"$input")" = Bash ] || exit 0
command=$(jq -r '.tool_input.command // ""' <<<"$input")
grep -qE '(^|[;&|] *)git( -C [^ ]+)? commit\b' <<<"$command" || exit 0

dir=$(jq -r '.cwd // ""' <<<"$input")
# The directory the commit runs in: the last cd before the commit, not after.
before=${command%%git commit*}
before=${before%%git -C * commit*}
cd_to=$(grep -oE '(^|[;&|] *)cd +[^ ;&|]+' <<<"$before" | tail -1 | sed -E 's/.*cd +//' || true)
c_to=$(grep -oE 'git -C [^ ]+ commit' <<<"$command" | tail -1 | awk '{print $3}' || true)
for next in "$cd_to" "$c_to"; do
  [ -z "$next" ] && continue
  case $next in /*) dir=$next ;; ~*) dir="$HOME${next#\~}" ;; *) dir="$dir/$next" ;; esac
done
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || exit 0
# A merge brings files already committed, and gated, on their own branch.
git -C "$dir" rev-parse -q --verify MERGE_HEAD >/dev/null && exit 0

added=$(git -C "$dir" diff --cached --name-only --diff-filter=A |
  grep -E '(^|/)src/.*\.usecase\.ts$|(^|/)src/components/.*\.tsx$' |
  grep -vE '(^|/)(__tests__|test|tests)/|\.test\.|\.spec\.|/components/ui/' || true)
[ -z "$added" ] && exit 0

untested=()
while IFS= read -r file; do
  stem=$(basename "$file"); stem=${stem%.tsx}; stem=${stem%.ts}; stem=${stem%.usecase}
  # A test counts when its path or its content names the file: a use case is
  # usually reached through its routes by a test named for it.
  if ! git -C "$dir" ls-files --cached -- '*.test.ts' '*.test.tsx' '*.spec.ts' '*.spec.tsx' | grep -qF -- "$stem" &&
    ! git -C "$dir" grep -q --cached -F -e "$stem" -- '*.test.ts' '*.test.tsx' '*.spec.ts' '*.spec.tsx' 2>/dev/null; then
    untested+=("$file")
  fi
done <<<"$added"

[ ${#untested[@]} -eq 0 ] && exit 0
echo "Refused: these new files have no test that names them. Write the failing test first, see it fail, then commit both: ${untested[*]}" >&2
exit 2
