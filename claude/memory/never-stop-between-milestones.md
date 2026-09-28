---
name: never-stop-between-milestones
description: "On a running build, report the finished milestone and dispatch the next in the same turn; never end a turn on an intention to dispatch"
metadata:
  node_type: memory
  type: feedback
---

While a build plan is being worked, the user does not want to be asked
whether to continue. When a milestone finishes: verify, merge, push, write a
short report, and start the next milestone in the same turn. Keep going
until told to stop.

The specific failure to avoid: writing "dispatching that now" and then ending
the turn without calling the tool. That happened on 2026-09-06 and the user
had to prompt for it. A closing sentence describing work not yet done is the
signal to do it before replying.

**Why:** the user is running this unattended for long stretches and every
stop costs a round trip they did not ask for.

**How to apply:** before sending any message that reports a finished
milestone, check that the next dispatch has already been made in the same
turn. See [[milestone-start-grounding]] for what that dispatch must carry.
