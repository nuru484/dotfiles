---
name: api-contracts
description: "Define or change HTTP request/response contracts between the Express API and its clients: wire types, errors, pagination, and compatibility. Use when an externally visible shape changes, not internal refactors."
---

# API Contract Conventions

The seam between backend and frontend. Pairs with `backend-conventions` and
`frontend-conventions`; this skill keeps the two **ends agreeing**.

Apply only the sections and checks relevant to the requested change. Existing
project contracts, provider choices, and installed versions take precedence over
these house defaults. Read linked skills only when their concern is involved.

## The core problem this prevents
The schemas are mirrored by hand (a Zod schema on the server, another on the
client). They drift. This skill makes the mirror **deliberate and checked**:
deliberate via shared contracts or linked documentation, and checked through
representative consumer/provider behavior tests. Confirm which checks actually exist
in CI before claiming drift is caught automatically.

## Self-audit checklist

```
SHAPE
[ ] Routes under a version prefix: /api/v1/...
[ ] Success envelope: { message, data }  (lists add meta + optional summary)
[ ] List meta: { total, page, limit, totalPages }
[ ] Error envelope: { status: "error", message, code?, details? }
[ ] Non-envelope success ONLY for sanctioned file streams (see File responses)
[ ] Field names, casing, and nullability identical on both ends
[ ] Wire formats followed: dates = ISO strings, money = integer minor units + currency

PAGINATION / FILTERING
[ ] List endpoints accept page, limit (capped), sort, and typed filters
[ ] Same query-param names the frontend's URL builder emits
[ ] Server validates + coerces query params (Zod) before use

CONTRACT SYNC
[ ] Request/response typed via shared I*Response / I*QueryParams interfaces
[ ] Frontend Zod schema mirrors the backend validation (tracked in contract documentation)
[ ] A field added/renamed/removed is updated on BOTH ends in the same change
[ ] Error `code` values come from one shared catalog
```

## URL & versioning
- All API routes live under **`/api/v1`** (the frontend base query already targets
  `PUBLIC_ENV.SERVER_URI + "/api/v1"`). Breaking changes bump the version; additive
  changes don't. Exception: `/health` and `/ready` stay at the root, unversioned -
  platform probes need stable paths (see `observability`); don't "fix" them.
- Resources are nouns, plural: `/donations`, `/donations/:id`. Sub-resources nest
  shallowly. Public vs admin routers are separate (see `backend-conventions`).

## Envelopes (identical wording on both ends)
```ts
// success - single (GET 200, PATCH/PUT 200)
{ message: "Donation retrieved", data: { /* ... */ } }
// success - create (POST 201)
{ message: "Donation created", data: { /* the created resource */ } }
// success - delete (200, not 204, so the envelope stays uniform)
{ message: "Donation deleted", data: null }
// success - list (empty list = 200 with data: [] and meta.total 0, never 404)
{ message: "Donations retrieved", data: [ /* ... */ ],
  meta: { total, page, limit, totalPages }, summary?: { /* ... */ } }
// error (produced by the central errorHandler)
{ status: "error", message: "Donor not found", code?: "NOT_FOUND", details?: { /* validation */ } }
```
The frontend's `extractApiErrorMessage` reads `data.message`; keep that field
present. The success envelope deliberately has NO `status` discriminator:
clients branch on HTTP status (RTK Query does this natively). Don't "fix" the
asymmetry by adding `status: "success"`.

## File responses & long-running work (the two sanctioned shape notes)

- **File responses and protocols:** file/download streams, SSE, redirects, and
  provider-defined webhook acknowledgements use their protocol's content type and
  status rather than a JSON envelope. The JSON list cap on `limit` does not apply to export
  streams. Ordinary application JSON responses retain the envelope.
- **Long-running work** (large exports, imports, report generation, bulk
  ops): `POST` responds `202 { message, data: task }` where the task carries
  `status: "PENDING" | "RUNNING" | "DONE" | "FAILED"` and `progress` (0-100);
  the client then polls the task's GET endpoint (e.g. `GET /exports/:id`),
  which returns the normal envelope. Full pattern: saas-integrations
  `reference/data-lifecycle.md`.

## Wire formats (the #1 real-world drift source)
JSON has no Date, Decimal, or BigInt; define how they cross the wire ONCE:
- **Dates/times**: ISO 8601 UTC strings (`2026-08-20T14:00:00.000Z`).
  Frontend Zod mirrors use `z.string().datetime()` (or `z.coerce.date()` when
  a Date object is genuinely needed); backend serializes Prisma `DateTime` as-is.
- **Money**: integer minor units + currency code (`amountMinor: 24500,
  currency: "GHS"`), matching the `database-migrations` storage rule. Both
  ends validate safe integer bounds and currency-specific precision; use a documented
  decimal/string representation when the range exceeds JavaScript safe integers. Convert to display units only at render
  (`Intl.NumberFormat`); convert from form input at the API call site.
- **Prisma `Decimal`** (non-money decimals): serialize as a string, document
  precision in the `I*` type; frontend parses explicitly.
- **BigInt**: avoid in API payloads; use string if unavoidable.
- **Nullability**: `null` means "cleared/absent value", omitted means "not
  provided" (PATCH semantics). Mirror optionality exactly (`.nullable()` vs
  `.optional()`).

## Pagination, filtering, sorting
- Standard query params: `page` (1-based), `limit` (validated + capped, e.g. ≤ 100),
  `sort` (`field:asc|desc`), plus typed domain filters.
- `search` (optional free text) is the standard param name for list search; the
  backend implementation ladder lives in backend-conventions `reference/backend-patterns.md`.
- The **server validates and coerces** these with Zod (`validateRequest(schema, "query")`)
  and the **frontend builds them with a typed URL helper** - the two must use the
  same param names. Never accept an unbounded `limit`.

## Keeping FE and BE in sync
- Treat the **backend validation as the source of truth**; the frontend Zod schema
  mirrors it and carries a documented link to the backend schema it mirrors.
- A change to a request/response shape is **one change touching both ends** - update
  the backend validation/type, the frontend Zod schema, and the shared `I*` types
  together. Don't ship one side.
- **Placement**: backend keeps schemas in `src/validations/` and types in
  `src/types/`; the frontend mirror lives in `validations/` and `types/` with
  the SAME file and type names, so the pair is greppable by name.
- If a monorepo/shared package is ever introduced, move the types/Zod there so the
  mirror becomes a single import. Until then, document the mirrored contract explicitly.

## The parity check (what makes the mirror "checked")
Run representative valid and invalid payloads against the actual provider schema
and consumer expectations, including nullability, coercion, transforms, and custom
refinements. Response fixtures or consumer tests should exercise wire serialization.
JSON Schema comparison is supplementary: transforms and custom refinements may not
be represented. A test of only the frontend schema against handwritten expectations
does not prove parity with the backend. If the backend is unavailable, report the
unverified dependency and preserve backward compatibility; do not invent evidence.

## Error code catalog
Use stable, machine-readable `code`s (not just prose messages) so the frontend can
branch: `VALIDATION_ERROR`, `NOT_FOUND`, `UNAUTHORIZED`, `FORBIDDEN`, `CONFLICT`,
`RATE_LIMITED`, `MISSING_TOKEN`, `TOKEN_EXPIRED`, `STALE_WRITE` (optimistic-lock
conflict; see backend-conventions `reference/backend-patterns.md`), `PLAN_REQUIRED`
(subscription entitlement gate). Map them from the backend's typed
error subclasses; extend the catalog in one place.

## When unsure
If a response shape is ambiguous, define the `I*Response` interface first and make
both ends conform to it - the type is the contract.
