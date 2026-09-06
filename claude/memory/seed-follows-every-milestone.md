---
name: seed-follows-every-milestone
description: "A milestone that adds models is not done until the demo seed covers them; seed before starting the next build"
metadata:
  node_type: memory
  type: feedback
---

On LFMS, a build-plan milestone that introduces new models is not finished
when its gate is green. The demo seed (prisma/demo/, run by seed:demo) must
be extended to cover the new models first, with rows for every enum value and
both sides of every boolean a screen reads, and only then does the next
milestone start.

**Why:** the user checks the UI by logging in and looking at real data
(2026-09-06). A screen with no rows behind it cannot be reviewed, so an
unseeded model blocks their half of the work even though the code is done.

**How to apply:** fold the seed extension into the milestone's own dispatch
rather than treating it as a separate job, or run a seed agent in a worktree
while the milestone's reconciliation finishes. Every seeded user keeps the
ADMIN_SEED_PASSWORD and is not forced to change a password or enrol MFA, so
each role can be logged into directly.
