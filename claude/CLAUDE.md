# Writing style

- NEVER use the em dash (—) in any writing whatsoever: chat responses,
  commit messages, PR titles/bodies, code comments, UI copy, documentation,
  generated content, everything. The ordinary hyphen (-) is fine and may be
  used whenever needed; when a longer pause is wanted, use a spaced
  hyphen ( - ), a comma, a colon, or restructure the sentence.

# Skill layers, ownership, and precedence

The skills come in two layers. **Universal skills** apply to any software
(app-blueprint, tdd, git-workflow, and these standards). **Stack profiles**
(backend-conventions, frontend-conventions, api-contracts, auth-conventions,
project-scaffold, saas-integrations, release-deploy, ci-cd, and the vendored
vercel-*/emil-* packs) encode decisions for the user's default web stack;
their descriptions scope them so they stay silent on other kinds of software
(an OS, a CLI, an embedded system) - there, the universal layer still applies
and architecture derives from that domain per app-blueprint Step 0.

When loaded skills disagree, exactly one owner wins - do not blend:

- Precedence: the repo's own code/docs > the user's personal skills >
  vendored third-party skills (vercel-*, emil-*) > plugin skills.
- Domain owners: responsive structure/content hardening = mobile-first-ui;
  interaction feel & motion = emil-design-eng (and animate);
  visual/creative direction = the frontend-design plugin;
  a11y/UX audit = web-design-guidelines; client data layer & frontend
  architecture = frontend-conventions; API shape = api-contracts;
  tests = tdd; commits/PRs = git-workflow.
- The user verifies rendered UI themselves: never start dev servers or take
  screenshots to self-verify UI, regardless of what any plugin skill
  (e.g. a "verification" skill) suggests. Functional checks (tests, curl)
  are fine.

# Engineering standards (apply to ALL code work, every stack)

These are the user's non-negotiable defaults. Skills refine them per domain;
nothing overrides them.

- **Production grade by default.** Build as if it ships to real users today:
  handle error paths, empty states, concurrency, and bad input, not just the
  happy path. "It works" is the floor, not the bar.
- **Follow the domain, not a template.** Model the actual thing being built
  before writing code: a trading system, a law-firm practice manager, and a
  custom database have different invariants, flows, and architectures. Derive
  entities, state machines, and module boundaries from the domain, then apply
  the stack conventions to that shape. Never force every app into one CRUD mold.
- **Consistency beats local cleverness.** One blessed way per concern in a
  codebase. Before writing the Nth endpoint, page, form, or test, read an
  existing one and match its shape exactly (naming, folder, envelope, states).
  If an existing pattern is bad, fix the pattern everywhere or record why,
  never fork a second style silently.
- **Stay current.** Verify latest stable versions before adding a dependency
  (`npm view <pkg> version`) and prefer current LTS runtimes; do not scaffold
  from memory of old versions or recommend deprecated APIs/libraries. When a
  framework has a current idiom (e.g. App Router, ESM), use it.
- **Tests lead.** Feature and bug-fix work is test-first by default (see the
  tdd skill): behaviors from the spec become failing tests before logic is
  written. Money, auth, permissions, and idempotency logic always get tests.
- **Design for the -ilities while writing, not after.** Security (validate at
  boundaries, least privilege, no secrets in code/logs), scalability (no
  N+1 queries, paginate lists, offload heavy work to queues), maintainability
  (small modules, one responsibility, explicit types), DRY (extract after the
  second repetition; shared helpers over copy-paste), and decoupling (depend
  on interfaces/boundaries, one-way layering, no hidden globals).
- **Efficient, not just working.** Choose the right data structure and query
  shape the first time (indexes, `select` narrowing, `Promise.all` for
  independent I/O, memo only where measured); avoid premature micro-tuning,
  but never ship a known O(n^2) or waterfall when the linear/parallel form is
  the same effort.
- **Responsive UI is part of correctness.** Any web UI must be designed for
  all screen sizes (phone first, tablet, desktop; see mobile-first-ui). A
  layout that breaks at any common viewport is a bug, not a polish item.
