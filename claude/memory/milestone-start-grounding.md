---
name: milestone-start-grounding
description: "Every build-plan milestone starts with the same grounding block: agents load the house skills and re-read the repo's rules, specs and conventions before writing anything"
metadata:
  node_type: memory
  type: feedback
---

On a long unattended build that walks a build plan level by level, the
grounding is repeated at the START of every milestone, not once at the
beginning of the run. Before any level begins, and again for each new agent
spawned for it, the prompt carries a block that says: load the house skills
by name, and re-read the repo's CLAUDE.md, README working rules, PLAN.md,
the build plan and the binding system design. The same holds for the main
session: load the skills covering whatever it is about to edit itself.

Skills by side: API takes backend-conventions, database-migrations,
api-contracts, tdd, security-hardening, observability; web takes
frontend-conventions, mobile-first-ui, api-contracts, design-taste,
web-design-guidelines, emil-design-eng. Precedence is always the repo's own
code and docs first, then the skills.

**Why:** the user watched a milestone get dispatched with only a pointer to
CLAUDE.md and asked for the skills to be used (2026-09-05); they then asked
that the reminder be repeated before every level rather than assumed to
carry over, because a long run drifts. Their words: do not trip on the
rules and specifications and conventions.

**How to apply:** treat the grounding block as a required part of the
dispatch template, alongside the gates to run and the commit rules. Never
shorten it to "follow the conventions" on the grounds that an earlier
milestone already said it. Above all it carries the user's standing UI bar:
professional, production grade, clean rather than cluttered, correct at 280,
375, about 768 with the sidebar open, and desktop. See
[[parallel-agents-both-repos]] for the dispatch shape and
[[lfms-ui-structure-principles]] for the console's own rules.
