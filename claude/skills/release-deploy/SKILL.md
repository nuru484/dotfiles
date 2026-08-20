---
name: release-deploy
description: >-
  Deployment and release-safety conventions for the user's backends (Express API
  + pg-boss worker on Render/Heroku) and their PostgreSQL databases - not Vercel
  frontend deploys (those live in the ci-cd skill). Apply AUTOMATICALLY when
  editing build/start/release scripts, Procfiles or render/heroku config,
  ordering migrations in a deploy, configuring env vars across environments,
  setting up the worker process, or planning a rollback. Use whenever the task
  is about getting backend code safely into production.
---

# Release & Deployment Conventions

How code reaches production safely. This skill owns the **backend API + worker
+ database** release path. Frontend (Vercel) deploys, CI pipelines, and
config-as-code files (render.yaml, Procfile, workflows) → `ci-cd`.
Migration *design* → `database-migrations`; this skill owns deploy *ordering*.

## Self-audit checklist

```
PROCESS MODEL
[ ] API (server) and worker (pg-boss) deploy as SEPARATE processes/dynos
[ ] Each has its own start command (npm start / npm run worker)

RELEASE ORDER
[ ] Migrations run in the platform's release step (Render Pre-Deploy Command /
    Heroku release phase), BEFORE new code serves traffic
[ ] Build: npm ci → build; Release: prisma migrate deploy; Start: web + worker
[ ] Migration is backward-compatible so old + new run together during rollout

CONFIG
[ ] All required env vars set in the target environment (ENV fails fast if not)
[ ] Secrets only in the platform's env store - never committed
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
Schema changes run before the new code serves traffic, in the platform's
**dedicated release step** - Render: the service's **Pre-Deploy Command**
(NOT the build command: builds also run for previews and parallel builds);
Heroku: the **`release:` phase** in the Procfile.

```bash
# Build step:            npm ci && npm run build   (ci, not install: lockfile-exact)
# Release/pre-deploy:    npx prisma migrate deploy
# (prisma generate runs in postinstall so the client matches the schema)
# Start:                 npm start (web) / npm run worker (worker)
# Seeding: run the idempotent seed once per environment as a manual/one-off
# command (heroku run / Render shell), compiled or via tsx - not on every deploy.
```
- `migrate deploy` only - **never** `migrate dev` in production.
- Seeds must be **idempotent** (upsert the default admin; don't duplicate).
- Because migrations are backward-compatible (`database-migrations`), a half-rolled
  deploy or a rollback never meets a schema it can't read.
- Canonical render.yaml / Procfile / workflow files: `ci-cd` → `reference/platforms.md`.

## Configuration & environments
- Every required variable lives in the platform's env store; the typed `ENV`
  module fails fast at boot if one is missing - treat a failed boot as the system
  working as intended.
- Verify per-environment values explicitly: `DATABASE_URL`, `CORS_ACCESS`,
  `COOKIE_DOMAIN`, frontend/callback URLs, provider keys. Staging ≠ production.
- Never commit secrets; never log them (see `observability`).

## Resilience & rollback
- Implement graceful shutdown in both processes (drain, close pg-boss, disconnect
  Prisma) so platform restarts/deploys don't sever in-flight work.
- Expose `/health` (liveness) and `/ready` (checks DB + queue, 503 when not
  ready; shapes in `observability`); point the platform's health check at `/ready`.
- Keep deploys revertible: small releases, backward-compatible migrations, and a
  known previous build to roll back to. If a migration would block rollback, split
  it (expand/contract) rather than shipping it.
- Executing a rollback: `heroku releases:rollback vNN`, Render's "Rollback to
  this deploy", `vercel rollback` for the frontend - exact commands and the
  post-rollback smoke check live in `ci-cd`. After any rollback, verify `/ready`
  and one core flow before walking away.

## When unsure
If you can't roll back the release cleanly (because a migration is destructive or
config changed incompatibly), stop and restructure it before deploying.
