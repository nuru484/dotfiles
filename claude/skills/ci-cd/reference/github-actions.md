# GitHub Actions Workflows

Complete, drop-in workflow files for the house stack. Place them in
`.github/workflows/`. Both run the same npm scripts a developer runs locally,
so any red CI check reproduces with one local command.

## backend-ci.yml

Express 5 + TypeScript ESM + Prisma + PostgreSQL + pg-boss. Integration tests
run against a real Postgres service container with migrations applied first.

```yaml
name: backend-ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: app_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10

    env:
      NODE_ENV: test
      DATABASE_URL: postgresql://postgres:postgres@localhost:5432/app_test
      # dummy values: the typed ENV fails fast without them. Every envRequired
      # variable in the scaffold's config/env.ts needs one here, or the typed
      # ENV boot-crashes `npm test`. Add a dummy for any new envRequired var
      # the repo introduces (e.g. EMAIL_FROM, PAYSTACK_SECRET_KEY).
      ACCESS_TOKEN_SECRET: ci-dummy-access-token-secret
      REFRESH_TOKEN_SECRET: ci-dummy-refresh-token-secret
      CORS_ACCESS: http://localhost:3000
      FRONTEND_URL: http://localhost:3000

    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v5
        with:
          node-version: 24 # keep in sync with package.json engines
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Generate Prisma client
        run: npx prisma generate

      - name: Apply migrations to the test database
        run: npx prisma migrate deploy

      - name: Lint
        run: npm run lint

      - name: Typecheck
        run: npm run typecheck

      - name: Test (unit + integration against Postgres)
        run: npm test

      - name: Build
        run: npm run build

      - name: Validate Prisma schema
        run: npx prisma validate

      # Fails if schema.prisma and prisma/migrations have diverged, i.e.
      # someone edited the schema without creating a migration (or vice
      # versa). Runs last because the shadow database gets reset: reusing
      # the service DB is safe only after the tests are done with it.
      - name: Migration drift check
        run: >-
          npx prisma migrate diff
          --from-migrations ./prisma/migrations
          --to-schema-datamodel ./prisma/schema.prisma
          --shadow-database-url "$DATABASE_URL"
          --exit-code

      # Policy decision: start non-blocking (continue-on-error: true) to
      # establish a baseline, then remove continue-on-error to make it a
      # blocking gate once existing advisories are resolved.
      - name: Audit dependencies
        run: npm audit --audit-level=high
        continue-on-error: true
```

Notes:
- The service container maps `5432:5432` to the runner host, so
  `DATABASE_URL` uses `localhost`. The health options make the job wait until
  Postgres actually accepts connections before steps run.
- `npx prisma migrate deploy` before tests means integration tests run on the
  exact schema production will get, and a broken migration fails CI, not the
  release phase.
- When the `api-contracts` parity script exists in the repo, add a step
  `run: npm run check:contracts` (or the script's actual name) after Build.

## frontend-ci.yml

Next.js App Router. The build uses placeholder `NEXT_PUBLIC_*` values: the
typed public env module requires the variables to exist at build time, and CI
only needs the build to compile, not to reach a real API. Vercel performs the
deploy build separately; this workflow is the merge gate.

```yaml
name: frontend-ci

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  NEXT_PUBLIC_SERVER_URI: http://localhost:4000

jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v5
        with:
          node-version: 24 # keep in sync with package.json engines
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Typecheck
        run: npm run typecheck

      - name: Test (Vitest component tests)
        run: npm test

      - name: Build
        run: npm run build

  # Optional: e2e smoke via Playwright. Keep it PR-only and @smoke-tagged so
  # it stays fast. Delete this job if the repo has no Playwright setup.
  #
  # IMPORTANT: the @smoke flow needs the API. Booting only the Next app in CI
  # leaves every API call failing, so the job would sit permanently red.
  # Default (shown here): run smoke against the PR's Vercel preview deployment,
  # with the Preview environment's NEXT_PUBLIC_SERVER_URI pointed at a stable
  # staging API. Alternative (sketched after the yaml): boot the backend and
  # Postgres inside this job. Never ship this job against a frontend with no
  # API behind it.
  e2e-smoke:
    needs: checks
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - uses: actions/setup-node@v5
        with:
          node-version: 24 # keep in sync with package.json engines
          cache: npm

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      # Vercel deploys every PR; this waits for the preview and outputs its
      # URL. Requires the repo to be linked to a Vercel project.
      - name: Wait for the Vercel preview deployment
        id: preview
        uses: patrickedqvist/wait-for-vercel-preview@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          max_timeout: 600

      - name: Run smoke tests against the preview
        env:
          PLAYWRIGHT_BASE_URL: ${{ steps.preview.outputs.url }}
        run: npx playwright test --grep @smoke
```

`playwright.config.ts` boots the app itself only for local runs; when
`PLAYWRIGHT_BASE_URL` is set (CI preview runs, post-deploy verification) it
targets that URL and skips `webServer`:

```ts
// playwright.config.ts
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:3000';

export default defineConfig({
  // ...
  use: { baseURL },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: 'npm run build && npm run start',
        url: 'http://localhost:3000',
        reuseExistingServer: !process.env.CI, // local runs reuse the dev API + app
        timeout: 120_000,
      },
});
```

Alternative to the preview URL: boot the full stack inside the e2e-smoke job.
Sketch (backend in a sibling checkout or monorepo path):

- Add the same `postgres:17` service container and dummy env block as
  backend-ci.
- Backend steps: `npm ci`, `npx prisma migrate deploy`, `npm run seed`, then
  start the API in the background (`npm run build && npm start &`) and wait
  for `curl -fsS http://localhost:4000/ready` to succeed.
- Set `NEXT_PUBLIC_SERVER_URI=http://localhost:4000`, leave
  `PLAYWRIGHT_BASE_URL` unset, and let Playwright's `webServer` boot the
  frontend.

That is slower and more moving parts per PR; prefer the preview-URL option
unless there is no stable staging API for previews to call.

Notes:
- Keep action versions current: `actions/checkout@v4`+ and
  `actions/setup-node@v4`+ (v5 shown above).
- Post-deploy verification reuses the same mechanism: run the smoke tag with
  `PLAYWRIGHT_BASE_URL` set to the production URL; see "Post-deploy
  verification" in SKILL.md.
