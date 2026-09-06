#!/usr/bin/env bash
# Refuses a commit message that names a tool, carries an attribution
# trailer, ornaments itself with an emoji, or runs on past the point.
# A deliberate exception goes through with: git commit --no-verify
set -u
msg_file="$1"
text=$(grep -viE '^[[:space:]]*#' "$msg_file")
fail=0

say() { echo "  $*" >&2; }

if printf '%s' "$text" | grep -qiE 'claude|anthropic|copilot|chatgpt|\bAI-(generated|assisted)\b'; then
  echo "commit rejected: the message names an AI tool." >&2
  printf '%s' "$text" | grep -niE 'claude|anthropic|copilot|chatgpt|\bAI-(generated|assisted)\b' | sed 's/^/    /' >&2
  fail=1
fi

if printf '%s' "$text" | grep -qiE '^[[:space:]]*(co-authored-by|generated[- ]with|signed-off-by[[:space:]]*:.*(claude|anthropic))'; then
  echo "commit rejected: the message carries an attribution trailer." >&2
  say "The work is the repo owner's; tooling credit stays out of the history."
  fail=1
fi

if printf '%s' "$text" | grep -qP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}\x{2190}-\x{21FF}\x{2713}\x{2714}\x{2715}\x{2716}\x{2605}\x{2606}\x{2726}]'; then
  echo "commit rejected: the message carries an emoji or an ornamental glyph." >&2
  fail=1
fi

if printf '%s' "$text" | grep -qP '\x{2014}'; then
  echo "commit rejected: the message uses an em dash." >&2
  say "Use a hyphen, a comma, a colon, or restructure the sentence."
  fail=1
fi

# The body is everything after the blank line that follows the subject.
body=$(printf '%s\n' "$text" | sed -n '2,$p' | sed '/^[[:space:]]*$/d')
lines=$(printf '%s' "$body" | grep -c . || true)
if [ "${lines:-0}" -gt 10 ]; then
  echo "commit rejected: the body runs to $lines lines." >&2
  say "Keep it to ten or fewer. Say why the change was made, not what every"
  say "file does; the diff already says that."
  fail=1
fi

exit "$fail"
