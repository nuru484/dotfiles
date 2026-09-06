---
name: run-targeted-tests
description: "During UI and iteration work run only the tests around what changed, not the whole suite"
metadata:
  node_type: memory
  type: feedback
---

When iterating on a change, run only the test files covering what was
touched. Keep the full gate for the end of a milestone, before a commit that
matters, or before a merge. The user does not want to wait several minutes
after every small edit.

**Why:** stated on 2026-09-06 during a UI pass; a full lfms-web gate is about
four minutes and a full lfms-api gate about eight, which is dead time on a
one-file change.

**How to apply:** name the specific test files. Run the full gate once, at the
end, and say plainly that it is the full run when reporting it.
