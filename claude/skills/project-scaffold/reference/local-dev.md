# Reference: Local Development Setup

Everything a fresh clone needs to reach a working login within minutes:
database container, env files, seeds, and the localhost cookie/CORS matrix.
Get the matrix right first; it is the number one cause of "login works in
Postman but not in the browser".

## Contents

1. [Port conventions](#1-port-conventions)
2. [docker-compose.yml](#2-docker-composeyml)
3. [Backend .env.example](#3-backend-envexample)
4. [Frontend .env.local.example](#4-frontend-envlocalexample)
5. [Localhost cookie / CORS matrix](#5-localhost-cookie--cors-matrix)
6. [prisma/seed.ts conventions](#6-prismaseedts-conventions)
7. [Running all processes](#7-running-all-processes)

---

## 1. Port conventions

Fixed so every env file, CORS origin, and README agrees without negotiation:

| Process | Port |
| --- | --- |
| Frontend (Next.js dev server) | 3000 |
| API (Express) | 4000 |
| PostgreSQL (docker) | 5432 |

## 2. docker-compose.yml

Postgres only; the app processes run on the host for fast reloads. The
healthcheck lets scripts (and humans) wait for readiness instead of racing
migrations against container startup; the named volume survives
`docker compose down`.

```yaml
services:
  postgres:
    image: postgres:17-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d app_dev"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres-data:
```

Rename `app_dev` (and the DATABASE_URL below) to the project's name. Wait for
health before migrating: `docker compose up -d --wait`.

## 3. Backend .env.example

Commit this file; never commit `.env`. Every variable in `config/env.ts`
appears here (the typed ENV fails fast on missing required vars, so the
example must be complete). Values are safe dev defaults; secrets are
placeholders naming the command that generates a real one.

```bash
# --- Runtime ---
NODE_ENV=development
PORT=4000
LOG_LEVEL=debug

# --- Database (matches docker-compose.yml) ---
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/app_dev

# --- Auth secrets: replace before first run ---
ACCESS_TOKEN_SECRET=generate-with: openssl rand -hex 32
REFRESH_TOKEN_SECRET=generate-with: openssl rand -hex 32
ACCESS_TOKEN_EXPIRY=30m
REFRESH_TOKEN_EXPIRY=7d

# --- Frontend origin (CORS + links in emails) ---
CORS_ACCESS=http://localhost:3000
FRONTEND_URL=http://localhost:3000

# --- Cookies: leave COOKIE_DOMAIN unset in dev (host-only cookies).
# --- In production set it to the parent domain, e.g. .example.com
# COOKIE_DOMAIN=
```

## 4. Frontend .env.local.example

```bash
NEXT_PUBLIC_SERVER_URI=http://localhost:4000

# only when media uploads are used (Cloudinary; see saas-integrations)
NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME=your-cloud-name
```

`PUBLIC_ENV` (lib/env.ts) throws at build if a listed variable is missing.
The api slice appends `/api/v1` to `NEXT_PUBLIC_SERVER_URI`, so the value is
the bare origin: no path, no trailing slash.

## 5. Localhost cookie / CORS matrix

Why this works: `localhost:3000` and `localhost:4000` are the SAME site
(cookies ignore ports), so `sameSite: "lax"` cookies flow between them
without `secure` or `sameSite: "none"`. The pieces must agree:

| Setting | Dev (localhost) | Production |
| --- | --- | --- |
| Cookie `sameSite` | `lax` | `lax` (app and API on sibling subdomains) |
| Cookie `secure` | `false` (plain http) | `true` (always) |
| Cookie `domain` | unset (host-only) via optional `ENV.COOKIE_DOMAIN` | parent domain, e.g. `.example.com` |
| `CORS_ACCESS` | `http://localhost:3000` | exact frontend origin, https |
| CORS `credentials` | `true` | `true` |
| Frontend fetch | `credentials: "include"` (api slice) | same |

Common failures: setting `COOKIE_DOMAIN=localhost` (browsers reject or
mishandle it: leave it unset), `secure: true` in dev (http silently drops the
cookie), or a CORS origin of `*` (credentialed requests require an exact
origin). The cookie policy implementation itself (`CookieManager`, which
reads these ENV values) and the cors middleware config are owned by the
`security-hardening` skill; this matrix is the local-dev ground truth they
must land on.

## 6. prisma/seed.ts conventions

Seeds are IDEMPOTENT: built from `upsert` on stable unique keys so re-running
never duplicates and never errors. A broken or once-only seed rots; a
re-runnable one doubles as the reset tool (`npm run seed` after any wipe).
Note the seed uses a plain `PrismaClient`, not the app's extended client: it
runs outside the app and may legitimately touch soft-deleted rows.

```ts
import { PrismaClient } from "@prisma/client";
// The hash helper comes from the app (house choice: see security-hardening).
// Never seed plaintext passwords, even in dev.
import { hashPassword } from "../src/utils/password.js";

const prisma = new PrismaClient();

// Representative demo data. In a real seed: ~15 rows, enough to exercise
// pagination past the default limit of 10, filters, and edge states.
const demoCampaigns = [
  { slug: "clean-water", title: "Clean Water", type: "FINANCIAL" },
  { slug: "school-supplies", title: "School Supplies", type: "IN_KIND" },
];

const main = async (): Promise<void> => {
  // 1. Default admin: fixed email as the stable key, safe to re-run.
  await prisma.user.upsert({
    where: { email: "admin@example.dev" },
    update: {}, // keep existing dev changes; update only via migrations
    create: {
      email: "admin@example.dev",
      fullName: "Dev Admin", // auth-conventions User fields: fullName + passwordHash
      role: "ADMIN", // prefer the Prisma-generated enum in real code
      passwordHash: await hashPassword("admin-dev-password"),
    },
  });

  // 2. Demo data: upsert each row on a natural key (slug, email,
  //    reference) so the seed stays idempotent.
  for (const campaign of demoCampaigns) {
    await prisma.campaign.upsert({
      where: { slug: campaign.slug },
      update: {},
      create: campaign,
    });
  }
};

main()
  .catch((err) => {
    console.error(err); // seeds run outside the app logger; console is fine here
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
```

Adapt models and demo data to the actual domain. Keep the admin credentials
dev-only and documented in the README.

## 7. Running all processes

First boot:

```bash
docker compose up -d --wait      # postgres, wait for healthy
cp .env.example .env             # then generate real secrets (openssl rand -hex 32)
npx prisma migrate dev           # create/apply migrations
npm run seed                     # idempotent, safe to re-run any time
```

Day-to-day, three processes (three terminals):

```bash
npm run dev        # API on :4000 (backend repo)
npm run worker     # pg-boss worker (backend repo)
npm run dev        # frontend on :3000 (frontend repo)
```

Optional: add `concurrently` (dev dependency, verify version per the version
rule) to the backend so `npm run dev:all` runs API + worker in one terminal:

```jsonc
"dev:all": "concurrently -n api,worker \"npm run dev\" \"npm run worker\""
```

Sanity check the boot: `curl http://localhost:4000/health` returns
`{ "status": "ok" }`, `curl http://localhost:4000/ready` returns
`{ "status": "ready" }` once Postgres is reachable, and logging in from
http://localhost:3000 sets the auth cookies.
