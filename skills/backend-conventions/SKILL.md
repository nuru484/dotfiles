---
name: backend-conventions
description: "Implement Express/Prisma routes, services, validation, queries, and transactions using the project conventions. Owns backend layering and data access; schema migrations and HTTP contract changes have separate skills."
---

# Backend layering and data access

Use the existing Express/Prisma architecture and naming. Routes compose middleware;
controllers translate HTTP input/output; services own domain decisions and typed
errors; the database enforces durable invariants. Services should not depend on
Express request/response objects unless an established boundary explicitly needs it.

Validate and coerce input at the boundary, then pass typed values and the verified
actor/context to services. Do not trust client-supplied ownership or tenant identity.
Return selected response fields rather than serializing an entire database model.

Keep transactions short, propagate the transaction client to collaborating helpers,
and keep network calls and HTTP side effects outside them. For coupled state and
jobs, use a proven transactional enqueue integration or an outbox; enqueueing after
a commit alone is not atomic. Choose concurrency controls that enforce the domain
invariant under competing requests, not just sequential happy paths.

Use the established error/envelope and environment modules; create missing helpers
only when the requested behavior needs them. Schema changes use database-migrations,
wire changes use api-contracts, and access behavior uses auth-conventions.

## Read by concern

- Names, layering, selects, imports: [reference/conventions.md](reference/conventions.md).
- Service/validation examples: [reference/services.md](reference/services.md).
- Typed errors and configuration: [reference/errors-env.md](reference/errors-env.md).
- Transactions and races: [reference/transactions.md](reference/transactions.md).
- Search, audit, idempotency, other cross-cutting patterns:
  [reference/backend-patterns.md](reference/backend-patterns.md).

These house recipes are examples to adapt to the installed version, not a mandate
to add every module. Soft deletion, queues, and audit events need domain reasons.

## Completion

Exercise the public behavior and relevant invalid/denied paths. For state-changing
logic, test affected constraints, rollback, duplicate requests, and competing writes
where applicable. Check response shape and bounded query behavior. Run relevant
project checks and report actual evidence rather than calling unrun code verified.
