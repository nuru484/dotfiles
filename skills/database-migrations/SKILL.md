---
name: database-migrations
description: "API and database skill sets: load before the first backend or schema edit of a session. Owns Prisma/PostgreSQL schema changes, migrations, backfills and recovery."
---

# Database & Migration Conventions

Pairs with `backend-conventions` (data *access*); this skill owns schema *design*
and migration *safety*. Security of data (encryption, PII policy) → `security-hardening`.

Apply only the sections and checks relevant to the requested change. Existing
project contracts, provider choices, and installed versions take precedence over
these house defaults. Read linked skills only when their concern is involved.

## Golden rule: migrations must be backward-compatible (expand → contract)

Old and new app code run at the same time during a deploy. A migration must not
break the currently-running version.

- **Expand, deploy, then contract.** To rename/drop/retype a column: (1) add the
  new column, (2) deploy code that writes both / reads new, (3) backfill, (4) a
  later migration drops the old column once nothing uses it.
- **Never** drop or rename a column/table in the same release that stops using it.
- Make columns nullable or give a default when adding to a non-empty table.

*Why:* zero-downtime deploys; a rollback never lands on a schema the old code can't read.

## Self-audit checklist

```
SCHEMA DESIGN
[ ] IDs and timestamps fit the entity; immutable logs/join tables may differ
[ ] Use soft deletion only where recovery/audit requirements justify it
[ ] Relations set onDelete/onUpdate explicitly (no silent defaults)
[ ] Enums (Prisma) for fixed sets - not free String columns
[ ] Money: integer minor units OR Decimal + an explicit currency column - never Float
[ ] @unique / @@unique on natural keys and idempotency references
[ ] Indexes on every FK and on columns used in WHERE/ORDER BY/filters
[ ] No over-indexing (each index costs writes) - index real query paths only

MIGRATION SAFETY
[ ] Change is backward-compatible (old code still runs against new schema)
[ ] No column drop/rename/retype in the same release that stops using it
[ ] New non-null column on a populated table has a default or a backfill plan
[ ] Backfill is batched/idempotent (p-map / chunks), not one giant UPDATE
[ ] Generated with --create-only, SQL reviewed, THEN applied
[ ] Destructive steps gated behind a separate, later migration
[ ] Unique/NOT NULL added only AFTER data is known clean (validate first)
```

## Schema conventions

- **Default columns** for mutable entities: `id`, `createdAt @default(now())`,
  `updatedAt @updatedAt`. Soft-deletable models add `deletedAt DateTime?`
  (the `backend-conventions` soft-delete extension scopes reads).
- **Relations**: always declare `onDelete`/`onUpdate` (`Cascade` for owned
  children, `Restrict`/`SetNull` where deletion shouldn't cascade). Decide, don't default.
- **Enums** for fixed sets (status, type, method) so the type system and DB agree.
- **Money**: store integer minor units (or `Decimal`) plus a `currency` column.
  Never `Float` for money.
- **Constraints**: `@@unique` for natural keys and idempotency refs (payment
  `transactionReference`). Choose indexes for real joins/filter/sort paths, accounting for composite indexes; name composite
  indexes (`@@index([...], name: "...")`).

## Migration workflow

```bash
# 1. Generate WITHOUT applying, so the SQL can actually be reviewed first
npx prisma migrate dev --name descriptive_change --create-only
# 2. Inspect prisma/migrations/<timestamp>_descriptive_change/migration.sql
#    (locks? backward compatible? matches intent?) - edit here if needed
# 3. Apply locally. In a non-interactive shell (an agent, CI) use deploy:
#    migrate dev can wait on a prompt nothing answers.
npx prisma migrate deploy
# Generate SQL without touching a database (drifted or shared dev DBs):
npx prisma migrate diff --from-schema <committed schema> --to-schema prisma/schema.prisma --script

# CI/CD applies, never edits:
npx prisma migrate deploy
```

- A foreign key or index added by hand in SQL is declared in the Prisma schema
  too, or the next generated migration drops it.
- Editing an applied but unpushed migration: refresh its checksum in the local
  `_prisma_migrations` and drop cached test template databases.
- Apply hand-written repair SQL atomically: `psql -1 -v ON_ERROR_STOP=1 -f file`.
- One migration = one coherent change with a **descriptive name** (not `init`
  for the 12th time).
- **Backfills** run as batched, idempotent scripts (use `p-map` for controlled
  concurrency), re-runnable without double-applying - not inline in a migration
  for large tables.
- Run `migrate deploy` **before** the new app boots (it runs in the dedicated release/pre-deploy
  step, never an ordinary build) so the schema is ready when traffic arrives.
- The generated client is NOT committed: `prisma generate` runs in
  `postinstall` and in the deploy pipeline, so the client always matches the
  installed schema.
- `migrate dev` needs a shadow database: on managed Postgres without CREATEDB
  rights, configure a separate shadow database in the location supported by the installed
  Prisma version (Prisma 7: prisma.config.ts), or develop against local docker Postgres (preferred).

## Lock safety on large/hot tables

Plain DDL can take table locks that stall production traffic:

- **Indexes on big tables**: CREATE INDEX CONCURRENTLY cannot run inside a
  transaction. Inspect the migration runner/version and SQL for transaction wrappers;
  Prisma's classic PostgreSQL migrate runner does not wrap SQL by default. Use a
  dedicated migration without BEGIN/COMMIT and verify how the installed runner sends
  statements. Do not invent a transaction opt-out flag or mark an index applied
  before verifying its existence and validity.
- **NOT NULL on PostgreSQL 17 and earlier**: add a CHECK (column IS NOT NULL)
  NOT VALID, validate it, then SET NOT NULL; a validated check can avoid a second
  scan. Adding/validating constraints still acquires locks; measure on representative
  data and configure bounded lock timeouts. Newer versions may support other forms.
- Check whether a default/type change rewrites the table. Large backfills need
  resumable batches, explicit reconciliation, and a separate release step.

Sources: [Prisma transaction defaults](https://www.prisma.io/blog/prisma-migrate-dx-primitives),
[PostgreSQL 17 ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html).

## When a deployed migration fails

`migrate deploy` failing mid-migration leaves it marked failed in
`_prisma_migrations` and BLOCKS all future deploys until resolved. Do not
edit applied migrations and never `migrate reset` against production.

```bash
npx prisma migrate status                       # see what's failed/pending
# If the failed migration did NOT partially apply (or you rolled its effects back):
npx prisma migrate resolve --rolled-back <migration_name>   # then fix + redeploy
# If you completed its work manually and verified it:
npx prisma migrate resolve --applied <migration_name>
# Baselining an existing database that predates migrations:
npx prisma migrate diff / migrate resolve --applied <initial_migration>
```

Diagnose why it failed (lock timeout? bad data for a new constraint?) before
resolving; the resolve command only records state, it does not fix data.

## When unsure
If a change can't be made backward-compatible in one step, split it into
expand/backfill/contract migrations across releases and say so - don't ship a
destructive one-shot.
