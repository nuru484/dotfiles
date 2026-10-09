# API and database skill set, in one page

Reading this satisfies the API/database skill gate. Load a full skill only
when a change turns on its concern (a tricky migration, a webhook, a new
auth path); project rules (CLAUDE.md, the repo's codebase guide) win.

## backend-conventions
- Routes compose middleware; use cases own decisions and typed errors; the
  database holds durable invariants. Validate at the boundary, pass typed
  values and the verified actor. Return selected fields, never whole models.
- Short transactions; pass the tx to helpers; no network calls inside;
  outbox or transactional enqueue for state + job. Concurrency control that
  holds under competing writers (version check, row lock, unique index).
- A role enum on a relationship is a vocabulary: write who may hold it,
  exclusions, disqualifying standing; enforce in one domain function on
  every write path (seeds too). Every reference is a FK, typed ref object,
  navigable both ways.
- Scripted edits replace an exact block asserted once; read git diff after.

## database-migrations
- Expand, deploy, contract; never drop/rename in the release that stops
  using it. New non-null column on a populated table: default or backfill.
- Explicit onDelete/onUpdate; enums for fixed sets; money as minor units or
  Decimal + currency; unique on natural keys and idempotency refs; index
  every FK and filter/sort path, no more.
- Generate with --create-only (or migrate diff), review the SQL, then apply
  with migrate deploy. Hand-written FKs/indexes are declared in Prisma too.
  Editing an applied unpushed migration: refresh its checksum.
- A failed deployed migration blocks deploys: diagnose, then migrate resolve.

## tdd
- One meaningful failing test through the public interface, see it fail for
  the right reason, least code to pass, next case, refactor green.
- Prioritise money, permissions and denied paths, state transitions,
  validation, concurrent writes, idempotency. Real database for races.
- In a big build wire and test one area at a time. Run the edited test file.
- Report the fail/pass cycle and targeted results; full gate at the end.

## api-contracts
- Envelopes: success { message, data } (+ meta for lists), error
  { status, message, code?, details? }; empty list is 200 with [].
- Dates ISO strings; money minor units or scaled string + currency;
  null = cleared, omitted = not provided. Stable error codes from one catalog.
- Lists: page, limit (capped), sort field:dir, typed filters, search.
- A shape change updates both ends in the same change.

## security-hardening
- Deny by default; permission per route; ownership/scope check in the use
  case for every id; walls answer not found.
- Zod on body, query, params, webhooks; sanitize rich text; escape email.
- Uploads: magic bytes, size cap, random names, never served raw.
- Webhooks: raw body, timing-safe signature, idempotent by event id, fast 2xx.
- No secrets/PII in code, logs, URLs; select minimal fields.

## observability
- Structured pino logs with objects, correct levels, no secrets/PII.
- requestId per request and into jobs; 5xx to the tracker, 4xx logged only.
- Jobs log what they did in one line when they did something.
