---
name: no-emoji-in-code
description: "User bans emoji everywhere in committed work (code, comments, logs, docs, headings, commit messages); only deliberate typographic UI glyphs like check/close/star are allowed"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 15360cf1-2d6f-4cd6-9610-3b0050270144
  modified: 2026-08-22T01:08:24.397Z
---

No emoji in anything committed: source, comments, JSDoc, README and docs,
log/console output, toast and error strings, seed script output, section
headings, test names, commit messages and PR bodies. Includes the
"status-looking" set (white heavy check mark, cross mark, warning sign,
party popper, seedling, rocket, calendar, lock). Full rule lives in
~/.claude/CLAUDE.md under "No emoji in code, comments, or docs".

**Why:** the user's words - "There's no way a human developer can simply be
writing that in a keyboard." Emoji ornament reads as machine output. Same
motive as [[code-voice-no-provenance-comments]].

**How to apply:** write the word instead (`Seed skipped`, not seedling +
text); severity belongs in the log level, not a glyph. KEEP deliberate
monochrome typographic glyphs that ARE the UI: `✓ ✕ ★ ☆ ✦ ♥ ♡ ☐` and
separators `· • →` - removing those empties a real element. Never use an
emoji as a placeholder image (found one as a no-photo thumbnail in
khadys-kitchen-frontend; left in place and flagged rather than emptying the
slot). Grep the diff for U+1F300-1FAFF, U+2600-27BF, U+2B00-2BFF, U+FE0F
before declaring done.
