# Platform Configuration & Rollback Reference

Deploy wiring for Render, Heroku, and Vercel, plus the exact rollback
commands. Release ordering rationale lives in `release-deploy`; this file is
the config.

## Render: render.yaml (config as code)

Commit `render.yaml` at the repo root so the whole service topology is
reviewable in PRs. Two services, one database, one shared env var group.

```yaml
services:
  - type: web
    name: app-api
    runtime: node
    plan: starter
    buildCommand: npm ci && npm run build
    # Runs after build, BEFORE the new version receives traffic. If it
    # fails, the deploy is aborted and the old version keeps serving.
    # Requires a paid instance type (not available on the free plan).
    preDeployCommand: npx prisma migrate deploy
    startCommand: npm start
    healthCheckPath: /ready
    envVars:
      - fromGroup: app-shared
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        fromDatabase:
          name: app-db
          property: connectionString

  - type: worker
    name: app-worker
    runtime: node
    plan: starter
    buildCommand: npm ci && npm run build
    # No preDeployCommand here: only ONE service runs migrations. The web
    # service owns them; the worker just starts on the migrated schema.
    # start:worker runs the compiled build (node dist/worker.js). Never use
    # the "worker" script here: it is tsx watch, a devDependency absent from
    # a production install, so it crashes at boot.
    startCommand: npm run start:worker
    envVars:
      - fromGroup: app-shared
      - key: NODE_ENV
        value: production
      - key: DATABASE_URL
        fromDatabase:
          name: app-db
          property: connectionString

databases:
  - name: app-db
    plan: basic-256mb
    postgresMajorVersion: "17"

envVarGroups:
  - name: app-shared
    envVars:
      # sync: false = value is set once in the dashboard, never in the repo.
      # Names map one-to-one to the typed ENV (config/env.ts); a name that
      # exists in no ENV module is dead config.
      - key: ACCESS_TOKEN_SECRET
        sync: false
      - key: REFRESH_TOKEN_SECRET
        sync: false
      - key: CORS_ACCESS
        sync: false
      - key: FRONTEND_URL
        sync: false
      - key: COOKIE_DOMAIN
        sync: false
      - key: RESEND_API_KEY
        sync: false
      # optional: only when payments are used
      - key: PAYSTACK_SECRET_KEY
        sync: false
      # optional: only when error tracking is wired (observability skill)
      - key: SENTRY_DSN
        sync: false
```

Notes:
- Using an external database (e.g. Neon, Supabase) instead: drop the
  `databases:` block and set `DATABASE_URL` with `sync: false` in the group.
- `healthCheckPath: /ready` means Render only routes traffic once the app
  reports DB and queue reachable, and zero-downtime deploys wait for it.
- Render dashboards can drift from the file; treat `render.yaml` as the
  source of truth and sync via "Blueprint" deploys.

## Heroku: Procfile + release phase

```procfile
release: npx prisma migrate deploy
web: npm start
worker: npm run start:worker
```

Notes:
- The `release` process runs on every deploy after the build, before any new
  dyno starts. A non-zero exit aborts the deploy: the old release keeps
  serving. Inspect a failed release with `heroku releases:output vNN -a <app>`.
- The worker dyno uses `start:worker` (compiled `node dist/worker.js`); the
  `worker` script is tsx watch, dev-only, and crashes on a production dyno.
- The Node buildpack runs `npm ci` and the `build` script automatically;
  keep `prisma generate` in a `postinstall` script so the client exists at
  build time.
- Scale both process types explicitly:
  `heroku ps:scale web=1 worker=1 -a <app>`.
- Config vars: `heroku config:set KEY=value -a <app>`; the typed ENV module
  crashes the dyno at boot if one is missing, which surfaces in
  `heroku logs --tail` immediately.

## Vercel project settings (frontend)

- Framework preset: Next.js; root directory set to the frontend package when
  in a monorepo. Build command stays the default (`next build`).
- Production branch: `main`. Every PR gets a preview deployment with a unique
  URL; use it for review, not as a staging environment contract.
- Env vars are defined per environment (Production, Preview, Development)
  and must map one-to-one to the typed public env names:
  `vercel env add NEXT_PUBLIC_SERVER_URI production` (repeat for `preview`
  and `development` with the right values), or set them in Project Settings
  -> Environment Variables. Pull local values with `vercel env pull`.
- Preview deployments call an API from a browser, so CORS applies: either
  add the preview URL pattern to the backend's `CORS_ACCESS` or point all
  previews at a stable staging API via the Preview-scoped
  `NEXT_PUBLIC_SERVER_URI`.
- Monorepo: use the "Ignored Build Step" (Project Settings -> Git) with
  `npx turbo-ignore` or a `git diff --quiet HEAD^ HEAD -- ./` check so
  backend-only commits do not trigger frontend deploys.

## Rollback command reference

Precondition (from `release-deploy`): migrations are expand/contract, so the
previous code version runs correctly on the newer schema. Roll back code
only; never try to "un-migrate" production.

### Heroku

```bash
heroku releases -a <app>              # list releases, newest first
heroku releases:info v42 -a <app>     # confirm what v42 contained
heroku releases:rollback v42 -a <app> # deploy v42's slug as a new release
```

Rollback creates a NEW release running the old slug; the release phase does
not re-run, so the schema stays as-is (which is exactly why expand/contract
matters).

### Render

- Dashboard: service -> Deploys -> pick the last good deploy -> "Rollback to
  this deploy".
- API:

```bash
curl -X POST "https://api.render.com/v1/services/<serviceId>/rollback" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"deployId": "<dep-id-of-last-good-deploy>"}'
```

Roll back the web and worker services together; they were built from the
same commit and should return to the same commit.

### Vercel

```bash
vercel ls <project>                 # find the previous production deployment
vercel rollback <deployment-url>    # point production back at it
```

Or in the dashboard: Deployments -> previous production deployment ->
"Promote to Production" (instant, no rebuild).

### After every rollback

```bash
curl -fsS https://<api-host>/ready    # must return 200
```

Then exercise one core flow end to end (login + one read + one write), and
confirm the error tracker has gone quiet before calling the incident closed.
