---
name: project-scaffold
description: "Bootstrap a new Express/Prisma backend or Next.js frontend, or add a required missing infrastructure module in that stack. Reuse existing architecture; do not scaffold unrelated modules or replace working infrastructure."
---

# Project scaffolding

Inspect the existing tree, package scripts, lockfile, framework docs, and project
instructions. Reuse working infrastructure. Add only what the requested behavior
needs; an absent module in this catalog is not itself a requirement to create it.

## Choose the route

- New house-stack app: [reference/bootstrap.md](reference/bootstrap.md), applying
  only the backend/frontend portions requested. Do not create an API for a static
  site or a worker for an app with no background processing.
- Backend env/errors/validation/pagination/client/lifecycle: find the named section
  in [reference/backend-infra.md](reference/backend-infra.md).
- Frontend API/store/providers/states: find the named section in
  [reference/frontend-infra.md](reference/frontend-infra.md).
- Local services, environment, and seeds:
  [reference/local-dev.md](reference/local-dev.md).
- Before using version-sensitive examples:
  [reference/version-compatibility.md](reference/version-compatibility.md).

These are implementation examples, not guaranteed compatible drop-ins. Preserve
existing contracts and filenames unless changing them is part of the task. Match
installed versions and generated-client paths. Do not upgrade dependencies just
because the example uses a different API.

## Integration boundaries

Use backend/frontend-conventions for module placement; auth-conventions for
identity; security-hardening for trust-boundary middleware; database-migrations
for schema work. Read these only when that concern is involved. Optional providers,
workers, uploads, Sentry, and soft deletion need actual product requirements.

## Verify the scaffold

Check generated imports and configuration, required scripts, typecheck/build, and
one real behavior through the new module. Database features need an isolated
migration/query check; browser rendering remains for the user's review. Document
setup commands and unresolved external dependencies without claiming they work.
