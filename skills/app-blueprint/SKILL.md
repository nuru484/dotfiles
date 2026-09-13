---
name: app-blueprint
description: "Plan or resume a substantial application or multi-feature build: domain invariants, acceptance criteria, dependencies, and vertical milestones. Use for build planning and execution sequencing, not small fixes or isolated edits."
---

# Application planning and execution

## Establish the scope

Read the user's brief, project instructions, existing plan, and implementation.
For an existing build, reconcile completed milestones with code and relevant
checks. Continue from the next unfinished requirement; do not re-scaffold.
A feature in an existing app inherits its architecture and deployment topology.

Identify actors, core workflows, data ownership, state transitions, and the hardest
invariants. For a CLI or library, omit web concerns. For a web app, add pages and
HTTP contracts only where the requested behavior requires them.

## Make a usable plan

Create PLAN.md for a substantial new build, or update the project's existing plan.
Use only applicable sections:

- Scope and non-goals; consequential assumptions and unresolved decisions.
- Domain entities, invariants, roles, and state transitions.
- Acceptance criteria phrased as observable outcomes, including denied and failure paths.
- Data/API/UI changes and integration dependencies.
- Ordered vertical milestones, each with completion evidence and remaining risks.
- Release requirements when release is part of the request.

Define criteria before implementation: for example, duplicate payment events
produce one ledger entry; another tenant cannot read the resource; a retry after
an uncertain provider response reconciles without charging twice.

When the brief leaves a reversible choice open, use existing conventions and
record it. Ask only about unresolved decisions with material behavioral, cost,
privacy, or compatibility consequences. Do not ask again about settled choices.

## Sequence by dependency and risk

Build a small end-to-end slice first. Add infrastructure only when needed by that
slice. Establish authentication first when features depend on identity; public
or offline tools do not need an invented login system. Add workers only for actual
background processing. Use the project's stack; the house web defaults are not a
reason to migrate an existing application.

For each milestone: implement a behavior through its data/API/UI layers as needed,
exercise its acceptance and failure cases, update the plan, then continue. Use tdd
for behavioral logic and the domain skill for the affected layer. Load integration,
security, or accessibility references only for the boundaries being changed.
Commit according to git-workflow and the user's authorized workflow.

## Completion and release

A milestone is complete when its criteria have evidence, not just files or checked
boxes. Required evidence depends on the feature: contract compatibility, denied
access, invalid input, concurrent writes, retry/idempotency, loading/error/empty
states, and targeted checks. Explain genuine coverage gaps.

For a release, additionally verify required CI/build checks, configuration,
migration compatibility, operational ownership, monitoring, and recovery steps.
Include backup/restore evidence for stateful changes where recovery depends on it.
Deploy only within authorization; otherwise report release readiness and remaining
release actions. Do not equate local test success with deployment success.

Use safe representative seed data if a demo is needed. Document how to provision
credentials securely, never real credentials. The user performs visual review;
record it as pending until supplied rather than claiming a clicked-through flow.
