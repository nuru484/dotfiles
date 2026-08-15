---
name: api-contracts
description: >-
  Conventions for the HTTP contract between the user's Express/Prisma backends
  and Next.js/RTK Query frontends — URL/versioning, request/response envelopes,
  pagination & filtering, error codes, and keeping frontend Zod schemas and
  TypeScript types in sync with the backend. Apply AUTOMATICALLY when adding or
  changing an endpoint, a request/response shape, a validation schema on either
  side, or query/pagination params. Use whenever FE and BE must agree on a shape.
---

# API Contract Conventions

The seam between backend and frontend. Pairs with `backend-conventions` and
`frontend-conventions`; this skill keeps the two **ends agreeing**.

## The core problem this prevents
The schemas are mirrored by hand (a Zod schema on the server, another on the
client). They drift. This skill makes the mirror **deliberate and checked**.

## Self-audit checklist

```
SHAPE
[ ] Routes under a version prefix: /api/v1/...
[ ] Success envelope: { message, data }  (lists add meta + optional summary)
[ ] List meta: { total, page, limit, totalPages }
[ ] Error envelope: { status: "error", message, code?, details? }
[ ] Field names, casing, and nullability identical on both ends

PAGINATION / FILTERING
[ ] List endpoints accept page, limit (capped), sort, and typed filters
[ ] Same query-param names the frontend's URL builder emits
[ ] Server validates + coerces query params (Zod) before use

CONTRACT SYNC
[ ] Request/response typed via shared I*Response / I*QueryParams interfaces
[ ] Frontend Zod schema mirrors the backend validation (and says so in a comment)
[ ] A field added/renamed/removed is updated on BOTH ends in the same change
[ ] Error `code` values come from one shared catalog
```

## URL & versioning
- All API routes live under **`/api/v1`** (the frontend base query already targets
  `${NEXT_PUBLIC_SERVER_URI}/api/v1`). Breaking changes bump the version; additive
  changes don't.
- Resources are nouns, plural: `/donations`, `/donations/:id`. Sub-resources nest
  shallowly. Public vs admin routers are separate (see `backend-conventions`).

## Envelopes (identical wording on both ends)
```ts
// success — single
{ message: "Donation retrieved", data: { /* ... */ } }
// success — list
{ message: "Donations retrieved", data: [ /* ... */ ],
  meta: { total, page, limit, totalPages }, summary?: { /* ... */ } }
// error (produced by the central errorHandler)
{ status: "error", message: "Donor not found", code?: "NOT_FOUND", details?: { /* validation */ } }
```
The frontend's `extractApiErrorMessage` reads `data.message`; keep that field present.

## Pagination, filtering, sorting
- Standard query params: `page` (1-based), `limit` (validated + capped, e.g. ≤ 100),
  `sort` (`field:asc|desc`), plus typed domain filters.
- The **server validates and coerces** these with Zod (`validateRequest(schema, "query")`)
  and the **frontend builds them with a typed URL helper** — the two must use the
  same param names. Never accept an unbounded `limit`.

## Keeping FE and BE in sync
- Treat the **backend validation as the source of truth**; the frontend Zod schema
  mirrors it and carries a comment naming the backend schema it mirrors.
- A change to a request/response shape is **one change touching both ends** — update
  the backend validation/type, the frontend Zod schema, and the shared `I*` types
  together. Don't ship one side.
- If a monorepo/shared package is ever introduced, move the types/Zod there so the
  mirror becomes a single import. Until then, the comment-linked mirror is the rule.

## Error code catalog
Use stable, machine-readable `code`s (not just prose messages) so the frontend can
branch: `VALIDATION_ERROR`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`,
`RATE_LIMITED`, `MISSING_TOKEN`, `TOKEN_EXPIRED`. Map them from the backend's typed
error subclasses; extend the catalog in one place.

## When unsure
If a response shape is ambiguous, define the `I*Response` interface first and make
both ends conform to it — the type is the contract.
