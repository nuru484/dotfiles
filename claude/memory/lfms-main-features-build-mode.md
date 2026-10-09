---
name: lfms-main-features-build-mode
description: "LFMS from 3 Oct - one module at a time: discuss it (scope, UI on existing patterns, enterprise depth), build it, push, then discuss the next; full suites only at module end before push; demo seed last"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 4a6cf081-fb13-4f37-9bd6-089a926c505f
  modified: 2026-10-03T16:44:30.001Z
---

Owner, 3 Oct 2026 (corrected the same day): NOT one plan built non-stop. For EVERY module: discuss it first (what it does, how the UI looks while following existing patterns, how extensive it must be to be enterprise grade), then build it, push it, then discuss the next one, in the agreed order. The owner closes and reopens the session between modules.

**Why:** the Documents restructure drifted and slowed everything; the owner wants each module shaped up front, then built fast.

**How to apply:**
- At the start of a session: bring the brief for the next module, wait for agreement, then build without stopping until that module is done.
- Targeted tests and targeted lint only while building; the full test suites, full lint and the build run only when the module is finished and about to be pushed.
- No demo seed work while building; the seed is written after everything is built.
- The order lives in lfms-api/docs/ROADMAP.md ([[lfms-roadmap-only-tracker]]); rule [[discuss-before-each-session]].
