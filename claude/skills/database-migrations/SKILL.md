---
name: database-migrations
description: >-
  Conventions for designing Prisma schemas and shipping safe PostgreSQL
  migrations in the user's backends. Apply AUTOMATICALLY when editing a
  schema.prisma, adding/changing a model/field/enum/index/relation, creating or
  running a Prisma migration, planning a backfill, or changing anything that
  alters the database shape. Use whenever a change touches the data model or a
  migration file.
---

# Database & Migration Conventions

Pairs with `backend-conventions` (data *access*); this skill owns schema *design*
and migration *safety*. Security of data (encryption, PII policy) → `security-hardening`.

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
[ ] Every model: id, createdAt @default(now()), updatedAt @updatedAt
[ ] Mutable/business models have deletedAt DateTime? (soft delete)
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

- **Standard columns** on every model: `id`, `createdAt @default(now())`,
  `updatedAt @updatedAt`. Soft-deletable models add `deletedAt DateTime?`
  (the `backend-conventions` soft-delete extension scopes reads).
- **Relations**: always declare `onDelete`/`onUpdate` (`Cascade` for owned
  children, `Restrict`/`SetNull` where deletion shouldn't cascade). Decide, don't default.
- **Enums** for fixed sets (status, type, method) so the type system and DB agree.
- **Money**: store integer minor units (or `Decimal`) plus a `currency` column.
  Never `Float` for money.
- **Constraints**: `@@unique` for natural keys and idempotency refs (payment
  `transactionReference`). Index FKs and filter/sort columns; name composite
  indexes (`@@index([...], name: "...")`).

## Migration workflow

```bash
# 1. Generate WITHOUT applying, so the SQL can actually be reviewed first
npx prisma migrate dev --name descriptive_change --create-only
# 2. Inspect prisma/migrations/<timestamp>_descriptive_change/migration.sql
#    (locks? backward compatible? matches intent?) - edit here if needed
# 3. Apply locally
npx prisma migrate dev

# CI/CD applies, never edits:
npx prisma migrate deploy
```

- One migration = one coherent change with a **descriptive name** (not `init`
  for the 12th time).
- **Backfills** run as batched, idempotent scripts (use `p-map` for controlled
  concurrency), re-runnable without double-applying - not inline in a migration
  for large tables.
- Run `migrate deploy` **before** the new app boots (it's in the build/release
  step) so the schema is ready when traffic arrives.
- The generated client is NOT committed: `prisma generate` runs in
  `postinstall` and in the deploy pipeline, so the client always matches the
  installed schema.
- `migrate dev` needs a shadow database: on managed Postgres without CREATEDB
  rights, set `shadowDatabaseUrl` in the datasource to a second database you
  provision, or develop against local docker Postgres (preferred).

## Lock safety on large/hot tables

Plain DDL can take table locks that stall production traffic:

- **Indexes on big tables**: `CREATE INDEX CONCURRENTLY` - which cannot run
  inside a transaction, while Prisma applies each migration in one. Isolate it
  in its own migration (via `--create-only`, edit the SQL) and check the
  installed Prisma version's docs for the current transaction opt-out; if the
  installed version has none, run the statement as a scripted release step
  instead of a Prisma migration, then record it with `migrate resolve
  --applied`. Small or new tables can index normally inside the migration.
- **NOT NULL / CHECK on populated tables**: two steps - add the constraint
  `NOT VALID` (instant), then `VALIDATE CONSTRAINT` in a later migration
  (scans without blocking writes).
- **Adding a column with a volatile default** rewrites the table on old
  Postgres; on 11+ constant defaults are metadata-only - still verify the
  generated SQL.

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
