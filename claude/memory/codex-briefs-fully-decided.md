---
name: codex-briefs-fully-decided
description: Every Codex lane brief carries every decision, how-to and UI direction (file to copy, routes, nav, layout, phone, states, don'ts); Codex only implements
metadata:
  type: feedback
---

Owner, 2 Oct 2026: "write a very detailed, decision making rules, how to and everything for the codex, and all it has to do is just the implementations. also the ui directions, what it should do and not do."

**Why:** Codex judgement drifts from the console's standard; review rounds cost more than a long brief.

**How to apply:** lane/RULES.md carries the shared parts (4a screen recipes with the file to copy, the don'ts list, 4b decision order). Each lane/S<n>.md has Decisions (data, states, permissions, settings), The API (every route), and a "Screens (build exactly this)" section naming route, nav entry and permission, the file to copy, columns, filters, actions and their dialogs-vs-pages, phone layout, and a "Do not" line. Owner also wants the lane kept full: queue more independent sessions as soon as the lane finishes ([[codex-lane-owns-sessions]]).

Owner, 3 Oct 2026: keep Codex busy with INDEPENDENT work, but "spec completely" so it never again builds as shallow as it built the mail. Each brief states enterprise depth explicitly: the whole firm workflow, every state change with preconditions, reasons and audit, every list searchable, linked entities, phone layout. A thin brief is the lead's fault, not Codex's.
