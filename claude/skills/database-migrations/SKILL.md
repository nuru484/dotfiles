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
and migration *safety*. Security of data (encryption, PII policy) → security skill.

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
[ ] Every model: id, createdAt (@default(now)), updatedAt (@updatedAt)
[ ] Mutable/business models have deletedAt DateTime? (soft delete)
[ ] Relations set onDelete/onUpdate explicitly (no silent defaults)
[ ] Enums (Prisma) for fixed sets — not free String columns
[ ] Money: integer minor units OR Decimal + an explicit currency column — never Float
[ ] @unique / @@unique on natural keys and idempotency references
[ ] Indexes on every FK and on columns used in WHERE/ORDER BY/filters
[ ] No over-indexing (each index costs writes) — index real query paths only

MIGRATION SAFETY
[ ] Change is backward-compatible (old code still runs against new schema)
[ ] No column drop/rename/retype in the same release that stops using it
[ ] New non-null column on a populated table has a default or a backfill plan
[ ] Backfill is batched/idempotent (p-map / chunks), not one giant UPDATE
[ ] Reviewed the generated SQL before applying (npx prisma migrate dev)
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
# Author + review SQL locally (inspect the generated migration before committing)
npx prisma migrate dev --name descriptive_change

# CI/CD applies, never edits:
npx prisma migrate deploy
```

- One migration = one coherent change with a **descriptive name** (not `init`
  for the 12th time).
- **Backfills** run as batched, idempotent scripts (use `p-map` for controlled
  concurrency), re-runnable without double-applying — not inline in a migration
  for large tables.
- Run `migrate deploy` **before** the new app boots (it's in the build/release
  step) so the schema is ready when traffic arrives.
- Generated client output is committed/generated in `postinstall`; keep
  `prisma generate` in the deploy pipeline.

## When unsure
If a change can't be made backward-compatible in one step, split it into
expand/backfill/contract migrations across releases and say so — don't ship a
destructive one-shot.
