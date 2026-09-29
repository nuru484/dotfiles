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
    # Only shell commands that write a file: in-place edits, redirects, copies
    # and moves, and python or node scripts that open a file for writing. The
    # working directory joins the command so relative paths name their repo.
    command=$(jq -r '.tool_input.command // ""' <<<"$input")
    writes=$(sed -E 's#[0-9]*>+ ?/dev/null##g; s#[0-9]*>&[0-9]##g' <<<"$command")
    grep -qE '(sed|perl) -i|>|\btee\b|(^|[;&|] *)(cp|mv|install) |open\([^)]*["'"'"'][wa]\+?["'"'"']|write_text|writeFileSync|writeFile\(' <<<"$writes" || exit 0
    cwd=$(jq -r '.cwd // ""' <<<"$input")
    # Relative paths in the command are read against the working directory.
    target="$command $(sed -E "s#(^|[[:space:]'\"(=])([A-Za-z_.][A-Za-z0-9_.-]*/[^[:space:]'\"),]*)#\1$cwd/\2#g" <<<"$command")"
    ;;
  *) exit 0 ;;
esac

# Agent config, dependency and build output never count as work on a side;
# a repository worktree under .claude/worktrees is work like any checkout.
grep -qE '/(\.claude|dotfiles|node_modules|\.next|dist)/' <<<"${target//\/.claude\/worktrees\//\/worktrees\/}" && exit 0

if grep -qE '(\.(tsx|jsx|css|scss|mdx)\b|/[^/ ]*(-web|-site|frontend)[^/ ]*/)' <<<"$target"; then
  side=web; required=$WEB
elif grep -qE '/[^/ ]*(-api|backend)[^/ ]*/([^ ]*/)?(prisma|migrations)/' <<<"$target"; then
  side=database; required=$DB
elif grep -qE '/[^/ ]*(-api|backend)[^/ ]*/[^ ]*\.(ts|js|mts|cts)\b' <<<"$target"; then
  side=API; required=$API
else
  exit 0
fi

# A subagent's Skill calls and reads are in its own transcript under the
# session's subagents directory, which the gate reads with the parent's.
logs=()
if [ -n "$transcript" ]; then
  logs+=("$transcript")
  sub="${transcript%.jsonl}/subagents"
  [ -d "$sub" ] && while IFS= read -r f; do logs+=("$f"); done < <(find "$sub" -name '*.jsonl')
fi
seen() { [ ${#logs[@]} -gt 0 ] && grep -qF -- "$1" "${logs[@]}"; }

missing=()
for skill in $required; do
  seen "\"name\":\"Skill\",\"input\":{\"skill\":\"$skill\"" || missing+=("$skill")
done

# The owner's engineering preferences are read before the first edit on any side.
unread=()
seen "dotfiles-agent-instructions/engineering.md" || seen "dotfiles/instructions/engineering.md" ||
  unread+=("$HOME/.config/dotfiles-agent-instructions/engineering.md")

# A web repository that keeps a pattern catalogue (docs/PATTERNS.md) is
# built from it: an edit there waits until the catalogue and the design
# rules beside it have been read in this session.
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
      # A worktree's catalogue is its main checkout's; either reading counts.
      main=${root%%/.claude/worktrees/*}
      if ! seen "\"file_path\":\"$root/docs/$doc\"" && ! seen "\"file_path\":\"$main/docs/$doc\""; then
        unread+=("$root/docs/$doc")
      fi
    done
  fi
fi

[ ${#missing[@]} -eq 0 ] && [ ${#unread[@]} -eq 0 ] && exit 0

[ ${#missing[@]} -gt 0 ] && echo "Refused: this is $side work. Load the $side skill set first (Skill tool, once per session): ${missing[*]}" >&2
[ ${#unread[@]} -gt 0 ] && echo "Refused: read these first (Read tool, once per session); on a web repository with a pattern catalogue, build from the example it names: ${unread[*]}" >&2
exit 2
