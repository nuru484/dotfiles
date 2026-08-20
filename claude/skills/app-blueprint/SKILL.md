---
name: app-blueprint
description: >-
  How to turn a system design, spec, feature list, or app idea into an
  executable build plan and drive it to production with minimal user
  guidance. Apply AUTOMATICALLY and ALWAYS when asked to build an app,
  system, module, or major feature from a description ("build me a...",
  "here is the design...", "implement this system"), when starting any
  multi-feature build, when unsure what order to build things in, or when
  a requirement is ambiguous mid-build. This skill owns planning,
  sequencing, default decisions, and the definition of done.
---

# App Blueprint: from design doc to production

This skill exists so an unattended build never stalls on a decision, never
guesses silently, and never ships a template where the domain needed a
different shape.

## Step 0: model the domain before touching the stack

Read the design/spec and write down (in PLAN.md, below) what the system
*actually is*, before any scaffolding:

- **Entities and their invariants**: what must always be true (a trade's
  filled quantity never exceeds its order quantity; a legal matter always
  belongs to exactly one client; a page in a storage engine is never
  half-written). Invariants become transactions, constraints, and tests.
- **State machines**: which entities move through states (order:
  pending -> partially_filled -> filled/cancelled; matter: intake -> active ->
  closed). Every state machine becomes an enum + guarded transitions in a
  service, never scattered booleans.
- **Flows**: the 3-8 core workflows end to end, as the user experiences them.
- **Roles and permissions**: who may do what, as a matrix.
- **The domain's hard part**: every system has one (trading: concurrency and
  money correctness; law firm: documents, deadlines, and confidentiality;
  custom database: durability and the read/write path). Name it and give it
  the most design attention, the earliest tests, and the strictest review.

*Why:* the stack conventions (backend-conventions, frontend-conventions) say
HOW to write code; only the domain says WHAT the modules, schema, and
architecture should be. A trading system may need an append-only ledger and
idempotent event handling; a law-firm system may need document versioning and
audit trails; a database engine is not a CRUD app at all and the web-stack
skills mostly do not apply. Architecture follows the domain, then conventions
follow the architecture.

## Step 1: write PLAN.md at the repo root

Always produce this file first and keep it current. Exact structure:

```markdown
# <App name> build plan
## Domain summary          <- entities, invariants, state machines, hard part
## Assumptions             <- every gap in the spec + the default you chose
## Data model              <- models, fields, relations, enums (schema-ready)
## Roles & permissions     <- matrix
## API inventory           <- every endpoint: method, path, auth, req/res shape
## Page map                <- every route/page, who sees it, key states
## Integrations            <- payments/email/media/jobs per saas-integrations
## Milestones              <- ordered vertical slices (below), each committable
## Production checklist    <- copied from this skill, checked before "done"
```

## Step 2: decide, record, proceed

An unattended build makes decisions; it does not stall and it does not guess
silently. The rule:

- If the spec answers it, follow the spec.
- If the spec is silent, take the **default decision** (table below or the
  owning skill's default), write it under `## Assumptions` with one line of
  reasoning, and continue.
- Stop and ask the user ONLY when a decision is (a) irreversible or expensive
  to change (payment provider with existing accounts, multi-tenancy model,
  data residency), or (b) contradicts something the spec explicitly says.

Default decisions when the design doc is silent:

| Concern | Default |
| --- | --- |
| Repo topology | Two repos/apps: Express API + Next.js frontend (house stack) |
| Database | PostgreSQL + Prisma |
| Auth | Cookie JWT access+refresh per `auth-conventions` |
| Payments/email/media/jobs | Per `saas-integrations` decision table |
| Background work | pg-boss |
| Styling/UI kit | Tailwind + shadcn/ui, mobile-first |
| Multi-tenancy | Single tenant unless the spec implies orgs/workspaces |
| IDs | cuid/uuid strings, never sequential ints in URLs |
| Money | Integer minor units + currency column (`database-migrations`) |
| Timezones | Store UTC, render local |

If the thing being built is NOT a web app (a CLI, a library, a database
engine, an ML pipeline), keep Step 0-2 and the standards below, drop the
web-stack defaults, and derive structure from the domain plus that
ecosystem's current best practices.

## Step 3: build in vertical slices, in this order

1. **Scaffold** both apps + local dev environment (`project-scaffold`).
2. **Schema** for the core entities (`database-migrations`), migrate, seed.
3. **Auth** end to end: register/login/refresh/logout + one protected page
   (`auth-conventions`). This is first because everything else depends on it.
4. **Features as vertical slices**, one at a time, hardest-domain-logic
   first: schema delta -> failing tests (`tdd`) -> service -> endpoint
   (`api-contracts`) -> frontend page/form -> states -> commit. A slice is
   done when it works end to end, not when its layer is done.
5. **Integrations** (payments, email, media) as their features demand.
6. **Hardening pass**: `security-hardening` checklist, `observability`
   checklist, a11y/perf self-check (`web-design-guidelines`), motion
   self-check against the `review-animations` bar, and `design-taste`
   pre-flight on every public marketing surface.
7. **CI/CD + deploy** (`ci-cd`, `release-deploy`), smoke test in production.

Commit at every milestone per `git-workflow`'s autonomous-build rule. Never
build all backends then all frontends (horizontal slicing): it hides
integration breakage until the end.

## Consistency protocol (the anti "do it differently every file" rule)

- Before writing the Nth instance of anything (endpoint, page, form, table,
  test, job), open the best existing instance and match it: same folder
  shape, naming, envelope, states, error handling.
- One blessed way per concern per codebase. The blessed ways for this stack
  are in the conventions skills; PLAN.md records any project-specific ones.
- If a better pattern is discovered mid-build, upgrade ALL existing instances
  in the same change (or record a TODO with reason in PLAN.md), never leave
  two styles coexisting silently.
- Reuse before reinvention: search for an existing helper/component before
  writing a new one; extract shared code after the second repetition.

## Currency protocol (stay modern, verify, don't trust memory)

- Before scaffolding or adding a dependency: `npm view <pkg> version` and
  check the framework's current major (Next.js, Prisma, Express). Use current
  stable, note the version in PLAN.md.
- Prefer maintained, current-idiom libraries; if a library is deprecated or
  superseded (e.g. moment -> date-fns/Temporal, request -> fetch), use the
  successor. When in doubt about an API that may have changed, check the
  package's docs/types in node_modules rather than guessing.

## Production completeness checklist (before declaring the build done)

```
[ ] Every list paginated; every query consumer has loading/error/empty states
[ ] Error pages: not-found.tsx, error.tsx, global-error.tsx; API 404 handler
[ ] Auth edge cases: expired token mid-action, logout everywhere, deep links
[ ] Domain invariants enforced in DB (constraints) AND tested
[ ] Seeds allow a full demo: admin user + representative data
[ ] Metadata/SEO on public pages (title template, canonical, OG, JSON-LD where
    a schema type fits); favicon + OG image; sitemap.ts + robots.ts; authed
    routes noindexed (frontend-conventions reference/a11y-seo.md)
[ ] Legal/utility pages if public users exist (privacy, terms, contact)
[ ] security-hardening + observability self-audits run and passing
[ ] CI green; deployed; /ready verified; smoke flow clicked through
[ ] PLAN.md assumptions section reviewed and surfaced to the user in summary
```

## When unsure

Ambiguity is resolved by Step 2, not by pausing. Surface all recorded
assumptions to the user in the final summary so they can correct any of them
cheaply.
