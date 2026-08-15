---
name: release-deploy
description: >-
  Deployment and release-safety conventions for the user's backends (Express API
  + pg-boss worker on Render/Heroku) and their PostgreSQL databases. Apply
  AUTOMATICALLY when editing build/start/release scripts, Procfiles or render/
  heroku config, ordering migrations in a deploy, configuring env vars across
  environments, setting up the worker process, or planning a rollback. Use
  whenever the task is about getting code safely into production.
---

# Release & Deployment Conventions

How code reaches production safely. Frontend (Vercel) deploys are owned by the
Vercel skill; this skill owns the **backend API + worker + database** release path.
Migration *design* → `database-migrations`; this skill owns deploy *ordering*.

## Self-audit checklist

```
PROCESS MODEL
[ ] API (server) and worker (pg-boss) deploy as SEPARATE processes/dynos
[ ] Each has its own start command (npm start / npm run worker)

RELEASE ORDER
[ ] Migrations run in the release/prebuild step, BEFORE new code serves traffic
[ ] Sequence: install → prisma migrate deploy → prisma generate → (seed if needed) → build → start
[ ] Migration is backward-compatible so old + new run together during rollout

CONFIG
[ ] All required env vars set in the target environment (ENV fails fast if not)
[ ] Secrets only in the platform's env store — never committed
[ ] Per-environment values (URLs, cookie domain, callback URLs) verified

RESILIENCE
[ ] Graceful shutdown on SIGTERM (drain requests, close workers, prisma.$disconnect)
[ ] Health/readiness endpoint used by the platform before routing traffic
[ ] A rollback plan exists (and the migration doesn't block rolling back)
```

## Two processes, always
- **Web**: the Express API (`npm start` → `node build/server.js`).
- **Worker**: the pg-boss background worker (`npm run worker` → `node build/worker.js`).
- They share the database but scale and fail independently. Long jobs (email,
  newsletters, nisab refresh) must not run in the web process.

## Release ordering (the safe sequence)
Run schema changes before the new code boots, e.g. the build/release step:
```bash
npm install
npx prisma migrate deploy      # apply pending migrations
npx prisma generate            # regenerate client
npm run seed                   # only if idempotent (e.g. ensure default admin)
npm run build                  # compile
# then platform starts: npm start (web) / npm run worker (worker)
```
- `migrate deploy` only — **never** `migrate dev` in production.
- Seeds must be **idempotent** (upsert the default admin; don't duplicate).
- Because migrations are backward-compatible (`database-migrations`), a half-rolled
  deploy or a rollback never meets a schema it can't read.

## Configuration & environments
- Every required variable lives in the platform's env store; the typed `ENV`
  module fails fast at boot if one is missing — treat a failed boot as the system
  working as intended.
- Verify per-environment values explicitly: `DATABASE_URL`, `CORS_ACCESS`,
  `COOKIE_DOMAIN`, frontend/callback URLs, provider keys. Staging ≠ production.
- Never commit secrets; never log them (see `observability`).

## Resilience & rollback
- Implement graceful shutdown in both processes (drain, close pg-boss, disconnect
  Prisma) so platform restarts/deploys don't sever in-flight work.
- Expose readiness so traffic only routes when DB/queue are reachable.
- Keep deploys revertible: small releases, backward-compatible migrations, and a
  known previous build to roll back to. If a migration would block rollback, split
  it (expand/contract) rather than shipping it.

## When unsure
If you can't roll back the release cleanly (because a migration is destructive or
config changed incompatibly), stop and restructure it before deploying.
