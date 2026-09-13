# Bootstrap recipes

Read version-compatibility.md first. Commands illustrate the house stack; install
only dependencies needed by the requested slice and preserve existing package managers.
Do not start a frontend dev server unless explicitly requested.

## Backend bootstrap (Express 5 + TypeScript + Prisma + pg-boss)

```bash
mkdir <api> && cd <api> && git init
npm init -y
npm i express zod pg-boss pino pino-http dotenv cookie-parser helmet cors @prisma/client
npm i -D typescript tsx prisma pino-pretty vitest @types/express @types/node \
  @types/cookie-parser @types/cors eslint @eslint/js typescript-eslint \
  prettier eslint-config-prettier
npx prisma init --datasource-provider postgresql
```

`package.json` essentials. Why: ESM everywhere, and the `#*` import map with a
`dist` condition lets the same specifiers resolve to `src/` in dev (tsx) and
`dist/` in production without a bundler:

```jsonc
{
  "type": "module",
  "engines": { "node": ">=24" },  // verify current LTS first (version rule)
  "imports": { "#*": { "dist": "./dist/*", "default": "./src/*" } },
  "scripts": {
    "dev": "tsx watch src/server.ts",
    "dev:worker": "tsx watch src/worker.ts",
    "worker": "node --conditions=dist dist/worker.js",
    "build": "tsc -p tsconfig.json",
    "start": "node --conditions=dist dist/server.js",
    "start:worker": "node --conditions=dist dist/worker.js",
    "seed": "tsx prisma/seed.ts",
    "test": "vitest run",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  // Configure seeding in prisma.config.ts for Prisma 7; see version-compatibility.md.
}
```

tsconfig highlights: `"module": "NodeNext"` and `"moduleResolution": "NodeNext"`
(real ESM, explicit `.js` extensions in imports), `"strict": true`,
`"noUncheckedIndexedAccess": true` (indexing may be undefined, so bad lookups
fail at compile time), `"outDir": "dist"`, `"rootDir": "src"`.

Lint/format: flat `eslint.config.js` composing `@eslint/js` and
`typescript-eslint` recommended configs with `eslint-config-prettier` last;
prettier formats, eslint lints, never both jobs in one tool.

Then adapt only required infrastructure modules from `backend-infra.md` (map
below) into the backend layout at the bottom of this file.

**Project documentation, when starting a repository:**
- Project agent entrypoints (AGENTS.md / CLAUDE.md as needed) point to the same
  domain documentation, existing plan, and check commands.
- A `README.md` skeleton (setup, run, test; deploy/ops sections filled in at
  the end of the build per app-blueprint's completeness checklist).

## Frontend bootstrap (Next.js App Router + React 19)

```bash
npx create-next-app@latest <app> --typescript --tailwind --eslint --app \
  --src-dir --import-alias "@/*"
cd <app>
npx shadcn@latest init
npx shadcn@latest add button skeleton sonner
npm i @reduxjs/toolkit react-redux async-mutex react-hook-form @hookform/resolvers zod
npm i -D vitest @testing-library/react @testing-library/jest-dom jsdom msw
```

create-next-app generates only `dev`, `build`, `start`, and `lint` scripts.
Add the two the ci-cd pipeline (lint -> typecheck -> test -> build) also
runs, so CI is green on a fresh repo instead of failing on missing scripts:

```jsonc
// package.json: add to "scripts"
"typecheck": "tsc --noEmit",
"test": "vitest run"
```

Then adapt required data-layer modules from `frontend-infra.md` into the
frontend layout below, and wire `StoreProvider` + `Toaster` into
`app/layout.tsx` as shown there.

## Module map

Every module below is named by the conventions skills. Its canonical code
lives in the listed reference section; read the relevant section before writing that module.

| Module | Target file | Source (section) |
| --- | --- | --- |
| Typed ENV + envRequired/envOptional/envNumber/envBool | `src/config/env.ts` | backend-infra.md 1 |
| HTTP_STATUS_CODES | `src/constants/http-status-codes.ts` | backend-infra.md 2 |
| CustomError + typed subclasses | `src/utils/errors.ts` | backend-infra.md 3 |
| errorHandler (+ handlePrismaError, redaction, errorId) | `src/middlewares/error-handler.ts` | backend-infra.md 4 |
| asyncHandler | `src/utils/async-handler.ts` | backend-infra.md 5 |
| validateRequest + validationMiddleware | `src/middlewares/validate-request.ts`, `validation-middleware.ts` | backend-infra.md 6 |
| paginate (parsePagination, buildMeta) | `src/utils/paginate.ts` | backend-infra.md 7 |
| pino logger | `src/utils/logger.ts` | backend-infra.md 8 |
| requestId middleware (pino-http) | `src/middlewares/request-id.ts` | backend-infra.md 9 |
| Prisma client + soft-delete extension + TransactionClient | `src/lib/prisma.ts`, `src/lib/soft-delete-extension.ts` | backend-infra.md 10 |
| pg-boss queue + jobs pattern | `src/lib/queue.ts`, `src/jobs/` | backend-infra.md 11 |
| app skeleton (order note, /health, /ready) | `src/app.ts` | backend-infra.md 12 |
| server + worker entrypoints (graceful shutdown) | `src/server.ts`, `src/worker.ts` | backend-infra.md 13 |
| PUBLIC_ENV | `src/lib/env.ts` | frontend-infra.md 1 |
| apiSliceTags + envelope types | `src/types/api.ts` | frontend-infra.md 2 |
| auth slice (userLoggedIn/userLoggedOut/authChecked) | `src/redux/auth/auth-slice.ts` | frontend-infra.md 3 |
| api slice (typed reauth base query) | `src/redux/api-slice.ts` | frontend-infra.md 4 |
| store + typed hooks + StoreProvider | `src/redux/store.ts`, `hooks.ts`, `components/providers/store-provider.tsx` | frontend-infra.md 5 |
| Feature api file (id-level tags) | `src/redux/<feature>-api.ts` | frontend-infra.md 6 |
| extractApiErrorMessage | `src/utils/api-error.ts` | frontend-infra.md 7 |
| Skeletons, EmptyState, ErrorState, toast wiring | `src/components/shared/` | frontend-infra.md 8 |
| useOnlineStatus + OfflineBanner | `src/hooks/use-online-status.ts`, `src/components/shared/offline-banner.tsx` | frontend-infra.md 8 |
| Error pages (not-found, error, global-error) | `src/app/not-found.tsx`, `error.tsx`, `global-error.tsx` | frontend-infra.md 9 |
| WidgetErrorBoundary (dashboard widget containment) | `src/components/shared/widget-error-boundary.tsx` | frontend-infra.md 9 |
| Sentry init (client/server/edge, inert when DSN unset) | `src/instrumentation-client.ts`, `src/instrumentation.ts`, `src/sentry.server.config.ts`, `src/sentry.edge.config.ts` | frontend-infra.md 9 |
| useUpload + FileUpload (progress, cancel, retry) | `src/hooks/use-upload.ts`, `src/components/shared/file-upload.tsx` | saas-integrations reference/media.md |

## Local dev bootstrap (full detail: `local-dev.md`)

1. `docker compose up -d` - postgres:17-alpine with healthcheck and volume.
2. `cp .env.example .env` (backend), `cp .env.local.example .env.local`
   (frontend); generate real secrets with `openssl rand -hex 32`.
3. `npx prisma migrate dev` then `npm run seed` (seed is idempotent upserts,
   safe to re-run).
4. Run the three processes: API `npm run dev` (port 4000), worker
   `npm run dev:worker`, frontend `npm run dev` (port 3000).

Default ports (preserve project overrides): frontend 3000, API 4000. The localhost cookie/CORS matrix
(sameSite lax, secure false, no COOKIE_DOMAIN, CORS_ACCESS=http://localhost:3000)
lives in `local-dev.md`; get it right or login fails on first boot.

## Folder layouts

Backend (matches `backend-conventions`; kebab-case filenames, role suffixes):

```
src/
  app.ts  server.ts  worker.ts
  config/         env.ts
  constants/      http-status-codes.ts
  controllers/    <feature>/<name>-controllers.ts, index.ts barrels
  routes/         <feature>/<name>-routes.ts, index.ts (mounts under /api/v1)
  services/       <feature>.service.ts, <feature>-query.service.ts
  validations/    <feature>/<name>-validation.ts
  middlewares/    error-handler.ts, request-id.ts, validate-request.ts,
                  validation-middleware.ts, authenticate-jwt.ts
  utils/          errors.ts, async-handler.ts, paginate.ts, logger.ts, mappers/
  lib/            prisma.ts, soft-delete-extension.ts, queue.ts
  types/          <feature>/<name>.types.ts
  mail/           templates and senders
  jobs/           <feature>/<action>.job.ts
  workers/        optional: per-feature worker registration
  notifications/  optional
prisma/           schema.prisma, migrations/, seed.ts
```

Frontend (matches `frontend-conventions`; `@/` alias, kebab-case):

```
src/
  app/            routes, layout.tsx (StoreProvider + Toaster), page.tsx,
                  not-found.tsx, error.tsx, global-error.tsx
  components/
    ui/           shadcn primitives
    providers/    store-provider.tsx
    shared/       skeletons.tsx, empty-state.tsx, error-state.tsx,
                  offline-banner.tsx, widget-error-boundary.tsx,
                  file-upload.tsx (when media uploads exist)
    <feature>/    data-table/, detail/, forms/
  hooks/          use-online-status.ts, use-upload.ts (when media uploads exist)
  lib/            env.ts, utils.ts (cn)
  instrumentation.ts, instrumentation-client.ts, sentry.server.config.ts,
  sentry.edge.config.ts (error tracking; frontend-infra.md 9)
  redux/          store.ts, hooks.ts, api-slice.ts, auth/auth-slice.ts,
                  <feature>-api.ts
  types/          api.ts, <feature>.types.ts
  validations/    <feature>-validation.ts
  utils/          api-error.ts
  static-data/
```
