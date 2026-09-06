#!/usr/bin/env bash
# PreToolUse hook: blocks `git commit` while the repo's quality gates fail.
# Runs whatever gate scripts the repo declares (lint, typecheck, test via
# package.json "scripts"), so a milestone commit can never land red.
# Escape hatch for a deliberate override (user-approved only):
#   CLAUDE_SKIP_COMMIT_GATE=1 git commit ...
set -u

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# The git invocation, matched only at a command position (start, or after
# && ; |) so text merely containing the phrase (git log --grep "git commit")
# is not gated. The option run picks up both `-C <path>` and `-c key=value`,
# so `git -C /path/to/repo commit` is gated like any other commit.
invocation='(^|&&|;|\|)[[:space:]]*(CLAUDE_SKIP_COMMIT_GATE=1[[:space:]]+)?git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$cmd" | grep -Eq "$invocation" || exit 0

# Escape hatch only as an env-assignment prefix on the commit itself, never
# as free text elsewhere in the command (e.g. inside a message).
skip='(^|&&|;|\|)[[:space:]]*CLAUDE_SKIP_COMMIT_GATE=1[[:space:]]+git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'
printf '%s' "$cmd" | grep -Eq "$skip" && exit 0
[ "${CLAUDE_SKIP_COMMIT_GATE:-0}" = "1" ] && exit 0

# Gate the repo the command actually writes to, not the session's directory:
# `git -C <path> commit` and a `cd <path> &&` prefix each retarget it, and
# gating the wrong repo both misses the real failure and blocks on someone
# else's.
target=$(printf '%s' "$cmd" | grep -oP 'git(\s+-c\s+\S+)*\s+-C\s+\K[^\s;&|]+' | head -1)
[ -n "$target" ] || target=$(printf '%s' "$cmd" | grep -oP '^\s*cd\s+\K[^\s;&|]+' | head -1)
[ -n "$target" ] || target=.
eval "target=$target" 2>/dev/null || exit 0
root=$(git -C "$target" rev-parse --show-toplevel 2>/dev/null) || exit 0
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
