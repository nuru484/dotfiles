---
name: check-ui-live
description: Standing rule (owner, 2026-09-28) — after every implementation that touches UI, check it myself in a browser (Playwright) at every width down to 344 before reporting it done; overrides the engineering default
metadata:
  type: feedback
---

After every implementation that changes a screen (a milestone, a small fix, a layout tweak), walk the new and changed screens myself in the running app (Playwright MCP against the demo firm: API on 4000 with worker, web on 3000, widths 344, 375, ~768 with the sidebar open, 1536), as the C1.0 walk asks, and fix what I find before calling a milestone done.

**Why:** 2026-09-28 the owner said "you should be checking the ui too", then "from now, the rule is to always check the ui after implementation". Check overflow (no page scroll at 344), structure and even spacing, typography, colour, and that each screen matches its pattern after I reported the rendered walk as owed to them because engineering.md says not to self-verify in a browser. The owner's direct instruction outranks that default.

**How to apply:** start one dev server of each (WSL memory is tight, see [[khadys-dev-testing-notes]] and [[machine-wsl-memory-setup]]), sign in as each seeded role, check every width, stop the servers after. Decisions the owner leaves open: use my recommendation and record it (see [[never-stop-between-milestones]]).
