---
name: seed-follows-every-milestone
description: "PAUSED 2 Oct 2026: no demo seed per session; the walk script makes its own records through the API, and the Desktop log lists items for the owner to create by hand; one demo pass when features are done"
metadata:
  node_type: memory
  type: feedback
---

From S8 (2 Oct 2026) the demo seed is NOT extended per session (owner: "cutting down on the demo will make the development time fast ... when we get the functionality and every is done, we can work on the demo").

Instead:
- The live walk creates the records it needs through the API at walk time (max-length names, every state), in the scratchpad script; nothing committed.
- Each Desktop log entry ([[session-log-on-desktop]]) ends with a short "Create these to try it" list of records the owner makes by hand in the GUI.
- Existing seed code stays; keep the demo-seed test green, but add no new demo stages.
- One full demo pass after the features are built (before v1).

**Why:** seeding cost 10-20% of each session (seed code plus demo-seed test churn); the owner will make the data by hand.

**How to apply:** skip prisma/demo work in every session until the owner asks for the demo pass. Earlier rule (a milestone is not done until the seed covers its models, 6 Sep) is suspended. Related: [[speed-without-subagents]].

5 Oct 2026 (owner): the pause is to save time, not because seeding is unwanted. Keep any seed code already written (the conveyancing seed from the Opus lane stays). When seeded data is needed to confirm how a UI looks, seed it then. Briefs for other agents should say so, so they do not spend time on seeding otherwise.
