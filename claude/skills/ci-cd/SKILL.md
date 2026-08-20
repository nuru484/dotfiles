---
name: ci-cd
description: >-
  CI/CD conventions for the user's stack: GitHub Actions pipelines (lint,
  typecheck, test against a real Postgres, build), deploying the Express +
  Prisma + pg-boss backend to Render or Heroku (web + worker), the Next.js
  frontend to Vercel, env vars per environment, preview deploys, and rollback.
  Apply AUTOMATICALLY when setting up or editing CI pipelines or GitHub
  Actions workflows, configuring builds or checks for a repo, wiring Vercel,
  Render, or Heroku projects, configuring env vars across environments,
  setting up preview deploys, or planning or performing a rollback.
---

# CI/CD Conventions

Owns the pipeline and the platform wiring. `release-deploy` owns release
ordering and the process model; `database-migrations` owns migration design;
`api-contracts` defines the FE/BE contract parity check this pipeline runs.
Full workflow YAML lives in `reference/github-actions.md`; platform config
(render.yaml, Procfile, Vercel settings, rollback commands) in
`reference/platforms.md`.

## Pipeline law
- Every push runs lint -> typecheck -> test -> build. No stage is optional:
  each catches a class of failure the others miss.
- PRs to `main` merge only when green. `main` is always deployable.
- CI runs the SAME commands a developer runs locally (`npm run lint`,
  `npm run typecheck`, `npm test`, `npm run build`), so every CI failure
  reproduces locally with one command instead of a CI-only mystery.
- `npm ci`, never `npm install`, in CI: it installs exactly the lockfile and
  fails on drift instead of silently rewriting it.
- Cache dependencies via `actions/setup-node` with `cache: npm`, not
  hand-rolled cache steps.

## Backend CI
- Integration tests hit a real Postgres: a `postgres:17` service container
  with a health check, `DATABASE_URL` pointed at it, and
  `npx prisma migrate deploy` run before tests, so tests exercise the real
  migrated schema instead of a mock.
- Guard the schema: `npx prisma validate`, then the drift check
  `npx prisma migrate diff --from-migrations ... --to-schema-datamodel ... --exit-code`,
  so `schema.prisma` and the migrations directory can never diverge silently.
- `npm audit --audit-level=high`: start non-blocking
  (`continue-on-error: true`) to establish a baseline, then flip it to
  blocking once the noise is cleared. Decide and record which mode the repo
  is in; a permanently-ignored audit step is worse than none.

## Frontend CI
- Typecheck + lint + `next build` with dummy `NEXT_PUBLIC_*` values: the
  typed public env module needs values to exist at build time, not to be real.
- Vercel builds separately on its own infra; the CI build is the merge gate.
  Do not skip it because "Vercel builds anyway": Vercel failures arrive after
  merge, CI failures arrive before.

## Deploy conventions
Backend on Render (config as code, `render.yaml`): a `web` service and a
`worker` service, `preDeployCommand: npx prisma migrate deploy` so the schema
updates BEFORE new code serves traffic (ordering per `release-deploy`),
`healthCheckPath: /ready`, shared vars in an `envVarGroup`.

Backend on Heroku: `Procfile` with `release: npx prisma migrate deploy`,
`web:`, and `worker:` processes. The release phase is Heroku's pre-traffic
hook: if it fails, the deploy never goes live.

Frontend on Vercel: production tracks `main`; every PR gets a preview deploy.
Env vars are set per environment (Production / Preview / Development) in the
dashboard or CLI, mapping one-to-one to the typed public env names
(`NEXT_PUBLIC_SERVER_URI`, ...). Previews call an API: either add preview
URLs to the API's `CORS_ACCESS` or point previews at a stable staging API.

## Environments & secrets
- Three tiers: dev (local), preview/staging, production. Config differs per
  tier; code does not.
- Secrets live ONLY in platform env stores and GitHub Actions secrets. Never
  in the repo, never echoed in CI logs (Actions masks registered secrets and
  nothing else).
- The typed ENV module fails fast at boot, so a missing var is a loud deploy
  failure, not a 3am runtime surprise. Treat a failed boot as the system
  working as intended.

## Contract parity
When the repo has the `api-contracts` parity script (it compares backend Zod
schemas' JSON shape to the frontend mirrors), run it as a CI step. It is the
only automated guard against silent FE/BE contract drift.

## Rollback
Precondition, from `release-deploy`: migrations are expand/contract, so the
previous code version runs fine on the newer schema. Roll back code, never
the database.
- Heroku: `heroku releases -a <app>` to find the last good release, then
  `heroku releases:rollback vNN -a <app>`.
- Render: dashboard -> service -> Deploys -> "Rollback to this deploy", or
  API: `POST /v1/services/{serviceId}/rollback`.
- Vercel: `vercel rollback <deployment-url>`, or promote a previous
  deployment from the dashboard.
After ANY rollback, smoke-check: `/ready` returns 200 and one core flow works
end to end. Exact commands per platform: `reference/platforms.md`.

## Post-deploy verification
- Hit `/health` (liveness) and `/ready` (DB and queue reachable) on the
  deployed URL.
- Run the Playwright `@smoke` tag against the deployed URL when configured.
- Watch the error tracker for a spike in the first minutes. A deploy is not
  done when the build finishes; it is done when production is quiet.

## Self-audit checklist

```
PIPELINE
[ ] Push runs lint -> typecheck -> test -> build; PRs to main require green
[ ] CI commands identical to local npm scripts (failures reproduce locally)
[ ] npm ci, not npm install; setup-node cache: npm

BACKEND CI
[ ] postgres:17 service container with health check; migrate deploy runs before tests
[ ] prisma validate + migrate diff drift check present (schema never diverges)
[ ] npm audit policy decided: non-blocking baseline or blocking gate

FRONTEND CI
[ ] typecheck + lint + build with dummy NEXT_PUBLIC_* values
[ ] CI build is the merge gate; the Vercel build is not the gate

DEPLOY WIRING
[ ] Migrations run pre-traffic (Render preDeployCommand / Heroku release phase)
[ ] Web and worker are separate services with separate start commands
[ ] Render healthCheckPath is /ready; Vercel envs set per environment
[ ] Preview URLs handled: CORS_ACCESS updated or a stable staging API used

SAFETY
[ ] Secrets only in platform stores and Actions secrets; never in logs or repo
[ ] Contract parity check wired as a CI step when the script exists
[ ] Rollback path known per platform; migrations are expand/contract
[ ] Post-deploy: /health + /ready + smoke run + error-tracker watch
```
