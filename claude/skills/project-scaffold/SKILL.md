---
name: project-scaffold
description: >-
  Canonical implementations of every infrastructure module the other skills
  reference by name, plus the bootstrap procedures for new repos and local dev.
  Apply AUTOMATICALLY when starting a new backend or frontend from scratch,
  bootstrapping a repo, setting up local dev (docker, env files, seeds), or
  when ANY module named by the conventions skills (errorHandler, paginate,
  validationMiddleware, soft-delete extension, api slice, store, logger,
  pg-boss setup) does not yet exist in the repo - read the canonical source
  here instead of inventing it.
---

# Project Scaffold

The source of truth for infrastructure code. `backend-conventions`,
`frontend-conventions`, `api-contracts`, and `observability` describe how these
modules are used; this skill carries their full canonical implementations so a
greenfield build never invents them. Copy a module from the reference file,
keep its name and contract intact, then extend it for the domain.

Scope boundary: helmet/cors/rate-limit configuration, cookie policy, and the
security middleware ordering are owned by the `security-hardening` skill;
migration workflow by `database-migrations`; tests by `tdd`. This skill wires
the seams (env vars, app skeleton, dev matrix) and defers those domains.

## Version rule (applies to every step below)

Before pinning any dependency version, check the latest stable release with
`npm view <pkg> version` instead of trusting memory: training data goes stale,
registries do not. Install by name (`npm i express`) so npm resolves current
versions, and set `engines.node` to the current LTS major (verify on
nodejs.org, do not recall it).

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
    "worker": "tsx watch src/worker.ts",
    "build": "tsc -p tsconfig.json",
    "start": "node --conditions=dist dist/server.js",
    "start:worker": "node --conditions=dist dist/worker.js",
    "seed": "tsx prisma/seed.ts",
    "test": "vitest run",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "prisma": { "seed": "tsx prisma/seed.ts" }
}
```

tsconfig highlights: `"module": "NodeNext"` and `"moduleResolution": "NodeNext"`
(real ESM, explicit `.js` extensions in imports), `"strict": true`,
`"noUncheckedIndexedAccess": true` (indexing may be undefined, so bad lookups
fail at compile time), `"outDir": "dist"`, `"rootDir": "src"`.

Lint/format: flat `eslint.config.js` composing `@eslint/js` and
`typescript-eslint` recommended configs with `eslint-config-prettier` last;
prettier formats, eslint lints, never both jobs in one tool.

Then copy the infrastructure modules from `reference/backend-infra.md` (map
below) into the backend layout at the bottom of this file.

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

Then copy the data-layer modules from `reference/frontend-infra.md` into the
frontend layout below, and wire `StoreProvider` + `Toaster` into
`app/layout.tsx` as shown there.

## Module map

Every module below is named by the conventions skills. Its canonical code
lives in the listed reference section; read it before writing the file.

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

## Local dev bootstrap (full detail: `reference/local-dev.md`)

1. `docker compose up -d` - postgres:17-alpine with healthcheck and volume.
2. `cp .env.example .env` (backend), `cp .env.local.example .env.local`
   (frontend); generate real secrets with `openssl rand -hex 32`.
3. `npx prisma migrate dev` then `npm run seed` (seed is idempotent upserts,
   safe to re-run).
4. Run the three processes: API `npm run dev` (port 4000), worker
   `npm run worker`, frontend `npm run dev` (port 3000).

Ports are fixed: frontend 3000, API 4000. The localhost cookie/CORS matrix
(sameSite lax, secure false, no COOKIE_DOMAIN, CORS_ACCESS=http://localhost:3000)
lives in `reference/local-dev.md`; get it right or login fails on first boot.

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
  app/            routes, layout.tsx (StoreProvider + Toaster), page.tsx
  components/
    ui/           shadcn primitives
    providers/    store-provider.tsx
    shared/       skeletons.tsx, empty-state.tsx, error-state.tsx
    <feature>/    data-table/, detail/, forms/
  hooks/
  lib/            env.ts, utils.ts (cn)
  redux/          store.ts, hooks.ts, api-slice.ts, auth/auth-slice.ts,
                  <feature>-api.ts
  types/          api.ts, <feature>.types.ts
  validations/    <feature>-validation.ts
  utils/          api-error.ts
  static-data/
```
