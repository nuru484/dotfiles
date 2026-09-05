---
name: code-voice-no-provenance-comments
description: "User's strong rule - code/comments must read as if they wrote it; no provenance (\"measured from the reference\", \"X pattern\"), process, or chat narration in any codebase"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 15360cf1-2d6f-4cd6-9610-3b0050270144
  modified: 2026-08-21T22:32:33.699Z
---

Comments must explain code or logic only. Never write provenance ("the
template's X", "measured from the reference", "ported from dms",
"khadys-kitchen pattern", "Hostily-inspired"), process/conversation ("as
requested", "per the decision", "the house rule"), or narrated history
("moved into a dialog, old links must not 404"). No sibling-repo prefixes
in identifiers (e.g. `kk-`). Full rule now lives in ~/.claude/CLAUDE.md
under "Code voice".

**Why:** the user said such comments are "AI slop": they read as a chat
between the developer and the AI, explain nothing about the logic, and
expose the code as generated. They own the work; it must read as theirs.

**How to apply:** port designs/patterns silently and describe what the
code does; state a rule rather than citing it; before declaring done, grep
the diff for template/reference/measured/pattern)/convention)/rule)/ported
and sibling repo names. On 2026-08-21 I cleaned ~120 such comments across
90 files in aesthetics-suites (see [[codebase-guide-per-repo]]).
