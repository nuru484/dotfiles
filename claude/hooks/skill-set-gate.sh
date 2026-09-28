#!/usr/bin/env bash
# PreToolUse gate: an edit on a side of the stack is refused until the
# session has loaded that side's skill set (instructions/engineering.md owns
# the sets). Loading a set once per session is enough; the transcript records
# each Skill call.
set -euo pipefail

WEB="frontend-conventions mobile-first-ui api-contracts design-taste web-design-guidelines emil-design-eng"
API="backend-conventions api-contracts tdd security-hardening observability database-migrations"
DB="database-migrations backend-conventions tdd"

input=$(cat)
tool=$(jq -r '.tool_name // ""' <<<"$input")
transcript=$(jq -r '.transcript_path // ""' <<<"$input")

case $tool in
  Edit | Write | MultiEdit | NotebookEdit)
    target=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")
    ;;
  Bash)
    # Only shell commands that write a file: in-place edits and redirects.
    target=$(jq -r '.tool_input.command // ""' <<<"$input")
    writes=$(sed -E 's#[0-9]*>+ ?/dev/null##g; s#[0-9]*>&[0-9]##g' <<<"$target")
    grep -qE '(sed|perl) -i|>|\btee\b' <<<"$writes" || exit 0
    ;;
  *) exit 0 ;;
esac

# Agent config, dependency and build output never count as work on a side.
grep -qE '/(\.claude|dotfiles|node_modules|\.next|dist)/' <<<"$target" && exit 0

if grep -qE '(\.(tsx|jsx|css|scss|mdx)\b|/[^/ ]*(-web|-site|frontend)[^/ ]*/)' <<<"$target"; then
  side=web; required=$WEB
elif grep -qE '/[^/ ]*(-api|backend)[^/ ]*/(prisma|migrations)/' <<<"$target"; then
  side=database; required=$DB
elif grep -qE '/[^/ ]*(-api|backend)[^/ ]*/[^ ]*\.(ts|js|mts|cts)\b' <<<"$target"; then
  side=API; required=$API
else
  exit 0
fi

missing=()
for skill in $required; do
  if [ -z "$transcript" ] || ! grep -q "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" "$transcript"; then
    missing+=("$skill")
  fi
done

# A web repository that keeps a pattern catalogue (docs/PATTERNS.md) is
# built from it: an edit there waits until the catalogue and the design
# rules beside it have been read in this session.
unread=()
if [ "$side" = web ]; then
  if [ "$tool" = Bash ]; then
    probe=$(grep -oE "/[^ \"']*-web[^ \"']*" <<<"$target" | head -1 || true)
    [ -z "$probe" ] && probe=$(jq -r '.cwd // ""' <<<"$input")
  else
    probe=$target
  fi
  dir=$probe
  [ -d "$dir" ] || dir=$(dirname "$dir")
  root=""
  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "." ]; do
    if [ -f "$dir/docs/PATTERNS.md" ]; then root=$dir; break; fi
    dir=$(dirname "$dir")
  done
  if [ -n "$root" ] && [ "$probe" != "$root/docs/PATTERNS.md" ]; then
    for doc in PATTERNS.md DESIGN-RULES.md; do
      if [ -z "$transcript" ] || ! grep -qF "\"file_path\":\"$root/docs/$doc\"" "$transcript"; then
        unread+=("$root/docs/$doc")
      fi
    done
  fi
fi

[ ${#missing[@]} -eq 0 ] && [ ${#unread[@]} -eq 0 ] && exit 0

[ ${#missing[@]} -gt 0 ] && echo "Refused: this is $side work. Load the $side skill set first (Skill tool, once per session): ${missing[*]}" >&2
[ ${#unread[@]} -gt 0 ] && echo "Refused: read the pattern catalogue and design rules first (Read tool, once per session), then build from the example they name: ${unread[*]}" >&2
exit 2
