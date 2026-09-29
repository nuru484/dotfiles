# Engineering preferences

## Scope and precedence

Follow the user's explicit choices and the active environment's instructions.
Within this library, project instructions and established architecture take
precedence over personal defaults; domain-specific conventions take precedence
over vendored examples. Preserve licenses and legally required attribution.

Skills load by side of the stack. Before the first edit on a side in a
session, load that side's whole set once. The set is the owner's standing rule
and outranks any single skill's description; the size of the edit does not
shrink it.

- Web (Next.js app or site, any page, component, form, slice or style):
  frontend-conventions, mobile-first-ui, api-contracts, design-taste,
  web-design-guidelines, emil-design-eng.
- API (Express/Prisma routes, services, workers, jobs): backend-conventions,
  api-contracts, tdd, security-hardening, observability, database-migrations.
- Database (Prisma schema, migrations, backfills, seed): database-migrations,
  backend-conventions, tdd.

Add auth-conventions when identity, access or tenancy changes, git-workflow
before committing, and verification-before-completion before reporting done.
Other skills load for the change they name. Within a loaded skill, read only
the supporting sections the change needs. Explicit-only skills stay
explicit-only; another skill must not silently invoke them.

| Concern | Owner |
| --- | --- |
| Domain, acceptance criteria, milestones | app-blueprint |
| Missing infrastructure / bootstrap | project-scaffold |
| Backend layering / queries | backend-conventions |
| HTTP contract | api-contracts |
| Identity / access / tenancy | auth-conventions |
| Schema / backfill safety | database-migrations |
| Frontend architecture / data flow | frontend-conventions |
| Responsive structure / overflow | mobile-first-ui |
| Visual direction / marketing composition | design-taste |
| Existing interaction polish | emil-design-eng |
| Specific web / native animation | animate / animate-expo |
| Accessibility and semantic audit | web-design-guidelines |
| Behavior tests / failure diagnosis | tdd / systematic-debugging |
| Boundary security / instrumentation | security-hardening / observability |
| CI configuration / release execution | ci-cd / release-deploy |
| Commit and PR authoring | git-workflow |

## Implementation

- Model the domain's real invariants before choosing abstractions. Retain the
  existing stack unless changing it is part of the task. New house web apps
  default to Express/Prisma + Next.js/RTK Query; other domains choose their own shape.
- Inspect an existing implementation before adding another endpoint, component,
  form, or test. Reuse working modules and conventions. Correct a flawed pattern
  within scope; record wider follow-up work rather than rewriting unrelated code.
- Implement the smallest complete behavior, including relevant error, empty,
  concurrency, and invalid-input paths. Add abstractions when they remove actual
  duplication or protect an invariant; repetition counts alone do not justify one.
- Use test-first development for testable behavioral changes. Money, permissions,
  tenant isolation, state transitions, and idempotency require negative-path tests.
  Static text/style changes need appropriate inspection, not tests of wording.
- Verify installed framework versions, types, and bundled docs before using APIs.
  For new dependencies, check maintained stable releases and compatibility with
  the existing runtime. Do not upgrade unrelated dependencies to satisfy a recipe.
  Reference snippets are patterns to adapt and check, not a tested SDK.
- Validate trust boundaries, keep secrets out of source/logs, bound queries and
  workloads, and avoid unnecessary waterfalls. Optimize hot paths using evidence.
- Continue independently on reversible decisions using project conventions.
  Ask when missing information materially changes behavior or authorization.
  Record consequential assumptions in the existing plan or final response; small
  edits do not require a new PLAN.md. Prior authorization remains valid.
- Build/review requests do not automatically authorize production mutations,
  purchases, messages, or publishing. Finish reviewable preparation first.

## Verification and delivery

Use existing project checks that cover the changed behavior and run required
release checks before release. Reuse passing evidence while the relevant code,
configuration, and environment remain unchanged. Separate pre-existing failures
from regressions. Report what passed, what failed, and what remains unverified.

UI work is walked live before it is reported done: drive the running app in a
browser (Playwright) at the project's widths (default 1440, 1024, 768, 390 and
344) with empty, seeded and maximum-length data, and reproduce a reported visual
defect live before fixing it. Static UI review is the pre-check, not evidence of
browser behavior or visual quality. Run one dev server at a time where memory is
tight, and stop it when the walk is done.

## Writing and code voice

- Be concise. Do not use em dashes in responses, code, or documentation.
- Comments explain non-obvious behavior and constraints, not chat history or
  provenance. Use project terminology; do not leak another project's identifiers.
  Preserve required source attribution and licenses in their proper files.
- No unsolicited assistant attribution trailers in commits or PRs. Describe the
  software change in the owner's voice, while retaining technically relevant names.
- No emoji or decorative status/star/check glyphs in committed code, UI strings,
  logs, docs, or commit/PR text. Use words, log levels, or the project's icon set.
  Inline SVG is an option when no appropriate icon exists. Punctuation in prose
  is fine. Icons need accessible labels when meaningful and aria-hidden when not.
