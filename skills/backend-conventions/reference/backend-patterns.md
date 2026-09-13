# Reference: Cross-Cutting Backend Patterns

Read the relevant section before adding search to a list endpoint, reaching
for a cache, guarding concurrent edits, storing a calendar date, logging a
security-relevant action, or being asked for API docs.

## Contents

1. [Search](#1-search)
2. [Caching](#2-caching)
3. [Optimistic locking](#3-optimistic-locking)
4. [Date-only values](#4-date-only-values)
5. [Audit log](#5-audit-log)
6. [API docs](#6-api-docs)

---

## 1. Search

List endpoints take `search` as a standard optional query param (the name is
owned by api-contracts; validate it with the rest of the query schema). Pick
the implementation rung by table size and need; do not jump rungs.

### Rung 1: ILIKE / contains (small tables, admin lookups)

```ts
where: search
  ? {
      OR: [
        { title: { contains: search, mode: "insensitive" } },
        { description: { contains: search, mode: "insensitive" } },
      ],
    }
  : {},
```

Fine for small tables (up to low tens of thousands of rows) and simple
substring needs; it sequential-scans, so it does not survive real growth.

### Rung 2: Postgres full-text (real search: ranked, multi-word)

A generated `tsvector` column + GIN index; query with
`websearch_to_tsquery` (understands quoted phrases and `-exclusions`) via
`$queryRaw`, or Prisma's `fullTextSearch` preview where the repo has it
enabled. Migration SQL (generate with `--create-only` and paste; see
database-migrations for CONCURRENTLY rules on big/hot tables):

```sql
ALTER TABLE "Post"
  ADD COLUMN "searchVector" tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce("title", '')), 'A') ||
    setweight(to_tsvector('english', coalesce("body",  '')), 'B')
  ) STORED;

CREATE INDEX "Post_searchVector_idx" ON "Post" USING GIN ("searchVector");
```

```ts
const hits = await prisma.$queryRaw<{ id: string; rank: number }[]>`
  SELECT id, ts_rank("searchVector", websearch_to_tsquery('english', ${search})) AS rank
  FROM "Post"
  WHERE "searchVector" @@ websearch_to_tsquery('english', ${search})
    AND "deletedAt" IS NULL
  ORDER BY rank DESC
  LIMIT ${limit} OFFSET ${skip}
`;
```

`$queryRaw` BYPASSES the soft-delete extension: filter `"deletedAt" IS NULL`
(and any tenant scoping) yourself. Fetch ids + rank raw, then hydrate with a
normal `findMany({ where: { id: { in: ids } } })` so includes and mappers
stay on the typed path.

### Rung 3: pg_trgm (fuzzy name lookup, typo tolerance)

For "find the donor even though the name is misspelled":

```sql
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX "Donor_fullName_trgm_idx" ON "Donor" USING GIN ("fullName" gin_trgm_ops);
```

```ts
const donors = await prisma.$queryRaw<{ id: string; fullName: string; score: number }[]>`
  SELECT id, "fullName", similarity("fullName", ${search}) AS score
  FROM "Donor"
  WHERE "fullName" % ${search} AND "deletedAt" IS NULL
  ORDER BY score DESC
  LIMIT 10
`;
```

Full-text and trigram solve different problems (words vs spelling): a search
box over prose gets rung 2, a person/entity name lookup gets rung 3. An
external engine (Meilisearch etc.) only when a design doc demands features
Postgres cannot deliver.

## 2. Caching

**The default is NO CACHE.** Correct data beats stale data, and indexed
Postgres queries in this stack are fast. The ladder, in order:

1. **Postgres + indexes first.** A slow endpoint almost always means a
   missing index, an N+1, or an over-wide select. Fix the query; never paper
   over it with a cache.
2. **Per-request dedup already exists frontend-side** (React `cache()` /
   RTK Query request dedup); do not add a server cache to solve a
   duplicate-fetch problem the client layer already solves.
3. **ETag / If-None-Match, ONLY for hot PUBLIC GET endpoints.** Express note:
   Express already generates a weak ETag for every `res.json`/`res.send`
   body (`app.set("etag")` defaults to `"weak"`), so conditional requests
   get `304 Not Modified` with zero extra code. Know what that buys:
   bandwidth, not compute - the handler and query still ran. Add
   `Cache-Control: public, max-age=...` only on public endpoints that
   tolerate the staleness window; never on authenticated responses.
4. **A shared store (Redis) enters ONLY when the spec demands cross-instance
   state** - shared rate-limit buckets, cross-instance invalidation,
   presence. Introducing it is an architecture decision: record it as an
   app-blueprint-style assumption (what it stores, TTLs, invalidation rule)
   when introduced; never slip it in as "just a cache".

## 3. Optimistic locking

For user-editable records where LOST UPDATES matter: two admins edit the same
row, the last save silently overwrites the first. Scope: use it ONLY where
the domain calls for that protection. Counters and quantity decrements stay
on the guarded-`updateMany` pattern from `transactions.md` - the version
column solves concurrent EDITS, not concurrent DECREMENTS.

```prisma
model Article {
  id      String @id @default(cuid())
  version Int    @default(0)   // bumped on every update; clients echo it back
  // ...
}
```

The client reads the record (version included), edits, and sends `version`
back with the update. The service guards on it:

```ts
export const updateArticle = async (input: IArticleUpdateInput, actorId: string) => {
  const { count } = await prisma.article.updateMany({
    where: { id: input.id, version: input.version, deletedAt: null },
    data: { ...input.changes, version: { increment: 1 }, updatedById: actorId },
  });
  if (count === 0) {
    // Row missing OR someone saved since this client loaded it.
    const exists = await prisma.article.findFirst({
      where: { id: input.id },
      select: { id: true },
    });
    if (!exists) throw new NotFoundError("Article not found");
    throw new ConflictError("This record was changed by someone else", {
      code: "STALE_WRITE",
      context: { articleId: input.id, staleVersion: input.version },
    });
  }
  return prisma.article.findUniqueOrThrow({ where: { id: input.id } });
};
```

On `STALE_WRITE` (409) the client refetches, shows or merges the newer state,
and the user reapplies their change. `STALE_WRITE` lives in the api-contracts
error-code catalog.

## 4. Date-only values

Calendar dates - birthdays, due dates, public holidays, invoice dates - are
DATE-ONLY end to end: `@db.Date` in Prisma, ISO `yyyy-mm-dd` strings on the
wire, `<input type="date">` values in forms. NEVER timestamps: a birthday
stored as midnight UTC renders as the previous day in every zone west of
UTC, and the corruption is silent and permanent.

```prisma
dueDate DateTime @db.Date   // Postgres DATE; no time, no zone
```

- Wire format: `z.iso.date()` (Zod 4) or a `yyyy-mm-dd` regex on both ends.
  Convert with ``new Date(`${value}T00:00:00Z`)`` where Prisma needs a Date
  object; serialize back with `.toISOString().slice(0, 10)`.
- Never run a date-only value through display logic that applies the
  viewer's zone (`new Date("2026-03-04").toLocaleDateString()` shows
  March 3rd west of UTC). Format from the string parts.
- **Scheduling in a user's local time** ("remind me at 9am") is the other
  case: store the UTC instant AND the IANA zone (`remindAt DateTime` +
  `timezone String`, e.g. `"Africa/Accra"`), because "9am next Tuesday"
  cannot be reconstructed from a UTC instant alone once DST or a zone
  redefinition moves the offset. Compute occurrences in the stored zone,
  convert to UTC to fire.

## 5. Audit log

`createdById`/`updatedById` stamps answer "who touched this row last"; they
cannot answer "what happened when". Security-relevant actions append an
`AuditLog` row: auth events (login, failed login, password reset), role and
permission changes, deletions (soft and hard), data exports, and any admin
cross-tenant access.

```prisma
model AuditLog {
  id         String   @id @default(cuid())
  actorId    String?             // null ONLY for system-initiated actions
  orgId      String?
  action     String              // "<feature>.<verb>": "auth.login-failed", "role.grant"
  targetType String              // "User", "Donation", ...
  targetId   String
  metadata   Json                // minimal context; never secrets, never full PII
  createdAt  DateTime @default(now())

  @@index([orgId, createdAt])
}
```

- **Same transaction as the action.** The audit write rides the mutation's
  `$transaction` (pass `tx`), so the log can neither record a rolled-back
  action nor miss a committed one.
- **Append-only.** No update or delete path exists for AuditLog, and it has
  no `deletedAt`: add it to the soft-delete extension's `UNSCOPED_MODELS`.
- Reads are an admin-only list endpoint filtered on `[orgId, createdAt]`.

```ts
// utils/audit.ts - the one helper every audited mutation calls
import type { TransactionClient } from "#lib/prisma.js";

interface IAuditEntry {
  actorId: string | null; // null only for system-initiated work
  orgId?: string;
  action: string;
  targetType: string;
  targetId: string;
  metadata?: Record<string, unknown>;
}

export const audit = (tx: TransactionClient, entry: IAuditEntry) =>
  tx.auditLog.create({ data: { ...entry, metadata: entry.metadata ?? {} } });
```

Usage inside a service:

```ts
await prisma.$transaction(async (tx) => {
  await tx.membership.update({ where: { id }, data: { role: "ADMIN" } });
  await audit(tx, {
    actorId,
    orgId,
    action: "role.grant",
    targetType: "Membership",
    targetId: id,
    metadata: { role: "ADMIN" },
  });
});
```

## 6. API docs

Default: NONE. The FE/BE Zod mirror (api-contracts) IS the contract, checked
by the parity test; a hand-written docs site is a third copy that starts
drifting the day it ships. When a spec genuinely demands docs for
THIRD-PARTY consumers (a public API, a partner integration), generate
OpenAPI FROM the backend Zod schemas (zod-openapi style: register the
existing schemas and routes, emit the spec at build time, serve it under
`/api/v1/docs`) rather than hand-writing YAML. The schemas stay the single
source of truth; the document is a build artifact regenerated in CI, never
edited by hand.
