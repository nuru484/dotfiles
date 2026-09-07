---
name: lfms-layout-corrections
description: "Layout mistakes the LFMS owner corrected by hand; they are written into lfms-web/CLAUDE.md and must not recur"
metadata:
  node_type: memory
  type: feedback
---

On 2026-09-06 and 2026-09-07 the LFMS owner reviewed real screens and
corrected a set of layout faults, several of which they said should have been
reasoned out rather than shipped. They are recorded in
`~/repos/lfms-web/CLAUDE.md` under "Layout rules the owner has already
corrected once", so any agent reading that file gets them.

The one they were most direct about: **every input in a form column is the
same width**. A field is never narrowed because its content is short.

Also: cancel and save share one row on every phone down to 280px; a register
puts search, filters and actions on one row with no record count above them;
a page draws its name in the top bar on a phone; a tablet takes its own
heading size; a description is one line and a real sentence; a form section
keeps its inner container in both the reading and editing views; dates use
the repo's date component and never the browser's.

**Why:** the owner asked that these be kept permanently so future sessions do
not repeat them, and said plainly they did not understand why the equal-width
rule had not been reasoned through in the first place.

**How to apply:** read that CLAUDE.md section before any UI work in lfms-web,
and add to it rather than to a memory file when a new rule is settled, so it
reaches subagents that never see this store. See [[concise-responses]] and
[[run-targeted-tests]] for how the same owner wants the work reported.
