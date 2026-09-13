# Detailed conventions

Apply only the sections relevant to the requested change. Existing project
architecture and installed APIs take precedence over these house defaults.

## Conventions (each with its *why*)

### Folder & naming
- Layout under `src/`: `config/ controllers/ routes/ services/ validations/
  middlewares/ utils/ lib/ types/ mail/ jobs/` (+ `workers/`, `notifications/`).
  Group by feature inside each (`controllers/donation/`, `services/`, `validations/posts/`).
- **File names: kebab-case + role suffix** - `*-routes.ts`, `*-controllers.ts`,
  `*.service.ts` / `*-query.service.ts`, `*-validation.ts`, `*.types.ts`. One
  extension, no spaces, no camelCase filenames.
- Exports are named for the action: `createAdminDonation`, `listFinancialDonations`.
- Per-feature `index.ts` barrels re-export the public surface. (Barrels are a
  **backend-only** convention: Node has no bundler cost. Do NOT mirror them in
  the Next.js app, where barrel files bloat bundles - see `frontend-conventions`.)
*Why:* predictable names make grep, imports, and onboarding trivial.

### Controllers (thin)
- Export `RequestHandler[]`: `[...validationMiddleware.create(schema), handler]`.
- Wrap handlers in `asyncHandler`. Pull params/body, call a service, respond with
  the standard envelope and an `HTTP_STATUS_CODES` constant.
*Why:* the HTTP layer is a thin adapter; everything reusable lives below it.

### Services (pure, typed) - see `services.md`
- One responsibility per function; mutations take an `actorId`.
- Reads vs writes split: `x.service.ts` (mutations) / `x-query.service.ts` (lists, filters).
- Return `Prisma.<Model>GetPayload<{ include: typeof xInclude }>`; define a shared `const xInclude`.
- Map DB rows to response DTOs via `utils/mappers/` - don't leak raw records.
  The **controller** applies the mapper before sending; services return typed
  rows. A mapper is required whenever the row carries fields clients must not
  see (audit columns, soft-delete flags, internal FKs); a row that is already
  the exact contract may pass through, but decide per model, once.
*Why:* pure, typed, framework-free functions are the testable, reusable core.

### Validation (Zod) - `services.md`
- Validate at the boundary with `validateRequest(schema, target)`; the coerced
  result is written back to `req` so handlers read typed values.
*Why:* one validation lib (Zod), parsed-and-typed once, reused as the service input type.

### Errors (throw, typed) - see `errors-env.md`
- Throw `NotFoundError` / `BadRequestError` / `ValidationError` / `ConflictError`
  / `UnauthorizedError` / … from services. The central `errorHandler` formats the
  response, redacts secrets, assigns an `errorId`, converts Prisma errors.
*Why:* one consistent error contract; handlers never reinvent error JSON.

### Env (typed, fail-fast) - see `errors-env.md`
- Add vars to the `ENV` object via `envRequired/envOptional/envNumber/envBool`.
  App reads `ENV`, never `process.env`. Never hardcode a value `ENV` already defines.
*Why:* misconfiguration fails at startup, not mid-request; config is typed and discoverable.

### Prisma & data
- Single extended client from `lib/prisma.ts`. Soft-deletable models carry `deletedAt`
  and rely on the soft-delete extension (reads auto-scope to non-deleted;
  `findUnique` is the deliberate "find deleted on purpose" seam).
- Use narrow `select` for existence checks (`select: { id: true }`).
*Why:* no accidental leakage of deleted rows; no over-fetching.

### Transactions & concurrency - see `transactions.md`
- Multi-step invariants run inside `prisma.$transaction(async (tx) => …)`; pass
  `tx` down to helpers (typed as `TransactionClient`).
- For stock/seat/balance decrements use an **atomic guarded `updateMany`**
  (`where: { …, field: { gte: n } }, data: { decrement: n }`) and assert
  `count !== 0` - never read-then-write.
*Why:* correctness under concurrency without manual locking.

### Responses
- Success: `{ message, data }`. Lists: `{ message, data, meta: { total, page,
  limit, totalPages }, summary? }`. Use a shared `paginate()` helper.
*Why:* clients get one predictable shape across every endpoint.

### Side effects → queue
- Email/SMS, post-commit cleanup, and other heavy I/O go through **pg-boss**
  workers, not inline in the request path.
*Why:* fast handlers, retryable side effects, request path stays pure-ish.

### Imports
- Use the `#*` → `./src/*` subpath map (`#services/…`, `#config/env.js`), not
  deep relative paths. ESM with explicit `.js` extensions.
*Why:* moves files without rewriting import chains; readable at a glance.

### Audit & idempotency
- Mutations stamp `createdById`/`updatedById` from the passed `actorId`.
- External/payment/webhook operations use a unique transaction/idempotency
  reference and look settlement up with `findUnique` so a retried webhook can't
  double-record.
*Why:* traceable writes; safe retries against payment providers.

### Cross-cutting patterns - see `backend-patterns.md`
- **Search**: list endpoints take the standard `search` query param; ladder =
  ILIKE/contains → Postgres full-text (tsvector + GIN) → pg_trgm fuzzy, by table size/need.
- **Caching**: default is NO cache; Postgres + indexes first, ETag only on hot
  public GETs, Redis ONLY when the spec demands cross-instance state.
- **Optimistic locking**: `version Int` + guarded `updateMany` → `ConflictError`
  (`STALE_WRITE`), only where lost edits matter; counters keep the quantity pattern.
- **Date-only values**: calendar dates are `@db.Date` + `yyyy-mm-dd` strings end
  to end, never timestamps; local-time scheduling stores the IANA zone too.
- **Audit log**: security-relevant actions append an `AuditLog` row inside the
  same transaction as the action; append-only, no updates or deletes.
- **API docs**: none by default (the Zod mirror is the contract); generate
  OpenAPI from the backend Zod schemas only when third parties demand docs.
*Why:* recurring decisions get one house answer instead of per-repo inventions.

### Observability & lifecycle
- Attach a per-request `requestId` (header + every log line) alongside the
  existing `errorId`.
- HTTP server and workers shut down gracefully on `SIGTERM`: stop accepting,
  drain in-flight work, `prisma.$disconnect()`.
*Why:* a client error maps to server logs; deploys don't sever live requests.

---

