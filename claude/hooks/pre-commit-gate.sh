#!/usr/bin/env bash
# PreToolUse hook: blocks `git commit` while the repo's quality gates fail.
# Runs whatever gate scripts the repo declares (lint, typecheck, test via
# package.json "scripts"), so a milestone commit can never land red.
# Escape hatch for a deliberate override (user-approved only):
#   CLAUDE_SKIP_COMMIT_GATE=1 git commit ...
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# Fast exit for anything that is not a commit. Match "git commit" only at a
# command position (start, or after && ; |) so text merely containing the
# phrase (git log --grep "git commit") is not gated. Known residual miss:
# `git -c x=y commit` - acceptable, Claude does not emit that form.
case "$cmd" in
  "git commit"*|*"&& git commit"*|*"; git commit"*|*"| git commit"*) ;;
  *) exit 0 ;;
esac

# Escape hatch only as an env-assignment prefix on the commit itself,
# never as free text elsewhere in the command (e.g. inside a message).
case "$cmd" in
  *"CLAUDE_SKIP_COMMIT_GATE=1 git commit"*) exit 0 ;;
esac
[ "${CLAUDE_SKIP_COMMIT_GATE:-0}" = "1" ] && exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
# Only gate Node repos that declare gate scripts; other repos pass through.
[ -f "$root/package.json" ] || exit 0
cd "$root" || exit 0

log=$(mktemp)
trap 'rm -f "$log"' EXIT

for gate in lint typecheck test; do
  if jq -e --arg g "$gate" '.scripts[$g] // empty | length > 0' package.json >/dev/null 2>&1; then
    if ! npm run "$gate" --silent >"$log" 2>&1; then
      jq -n --arg g "$gate" --arg tail "$(tail -c 1200 "$log")" \
        '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",
          permissionDecisionReason:("Commit blocked: npm run \($g) failed. Fix the failure and commit again (never bypass by deleting the gate; CLAUDE_SKIP_COMMIT_GATE=1 only with user approval). Output tail:\n\($tail)")}}'
      exit 0
    fi
  fi
done

exit 0
