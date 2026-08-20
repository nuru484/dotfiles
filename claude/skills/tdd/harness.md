# The Test Harness (house stack defaults)

Read this before writing the first test in a repo that has no test
infrastructure. These are the defaults; a repo's existing setup wins.

## Tooling defaults

| Layer | Tool | Why |
| --- | --- | --- |
| Runner (BE + FE) | **Vitest** | Fast, ESM/TS native, Jest-compatible API |
| API integration | **supertest** against the Express `app` | Real routes, middleware, validation, error handler in the loop |
| Component tests | **@testing-library/react** + Vitest | Behavior-level component testing |
| HTTP mocking (FE) | **MSW** | Mocks at the network boundary, not the RTK Query internals |
| E2E smoke | **Playwright** (chromium) | One real-browser pass over the core flows |
| Test DB | **Real PostgreSQL**, dedicated database | The DB is part of the behavior (constraints, transactions, soft-delete extension) |

Scripts: `"test": "vitest run"`, `"test:watch": "vitest"`,
`"test:e2e": "playwright test"`. Keep unit/integration fast enough to run on
every cycle.

## Backend: integration tests against a real Postgres

- `DATABASE_URL` for tests points at a dedicated database (e.g.
  `app_test` in the same docker-compose Postgres; CI uses a service
  container - see the `ci-cd` skill).
- Global setup runs `prisma migrate deploy` once; per-test isolation by
  TRUNCATE of all tables between tests (fast, simple, works with the
  soft-delete extension and pg-boss tables):

```ts
// tests/helpers/db.ts
import { prisma } from "#lib/prisma.js";

export const resetDb = async (): Promise<void> => {
  const tables = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public' AND tablename NOT LIKE '_prisma%'`;
  await prisma.$executeRawUnsafe(
    `TRUNCATE TABLE ${tables.map((t) => `"${t.tablename}"`).join(", ")} RESTART IDENTITY CASCADE`,
  );
};
```

- Canonical endpoint test (the app is exported WITHOUT `.listen()` from
  `app.ts` so supertest can drive it):

```ts
import request from "supertest";
import { beforeEach, describe, expect, test } from "vitest";
import { app } from "#app.js";
import { resetDb } from "./helpers/db.js";
import { createTestUser, authCookieFor } from "./helpers/auth.js";

beforeEach(resetDb);

describe("POST /api/v1/donations", () => {
  test("admin can record a donation", async () => {
    const admin = await createTestUser({ role: "ADMIN" });
    const res = await request(app)
      .post("/api/v1/donations")
      .set("Cookie", await authCookieFor(admin))
      .send({ donorName: "Ama", amountMinor: 5000, currency: "GHS" });
    expect(res.status).toBe(201);
    expect(res.body.data.amountMinor).toBe(5000);
  });

  test("non-admin is forbidden", async () => {
    const user = await createTestUser({ role: "USER" });
    const res = await request(app)
      .post("/api/v1/donations")
      .set("Cookie", await authCookieFor(user))
      .send({ donorName: "Ama", amountMinor: 5000, currency: "GHS" });
    expect(res.status).toBe(403);
    expect(res.body.status).toBe("error");
  });
});
```

- Helpers/factories live in `tests/helpers/`: `createTestUser`,
  `authCookieFor` (calls the real login or issueAuthTokens), and small
  factory functions per model with sensible defaults and overrides. No
  fixture dumps; build the data each test needs.
- pg-boss in tests: don't start the worker; assert the JOB WAS ENQUEUED
  (query the queue table or spy on the enqueue helper, a true boundary),
  and unit-test handlers by calling them directly with a typed payload.

## Frontend: component tests with MSW

Mock the network, not the app: render the real component tree (with the real
store) and let MSW answer the HTTP calls RTK Query makes.

```tsx
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";
import { renderWithStore } from "./helpers/render";

const server = setupServer(
  http.get("*/api/v1/donations", () =>
    HttpResponse.json({ message: "ok", data: [], meta: { total: 0, page: 1, limit: 10, totalPages: 0 } }),
  ),
);
beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test("shows the empty state when there are no donations", async () => {
  renderWithStore(<DonationsTable />);
  expect(await screen.findByText(/no donations yet/i)).toBeInTheDocument();
});
```

`renderWithStore` wraps render with a fresh store per test. Test the three
states (loading, error, empty) plus the happy path for every data component.

## E2E smoke (Playwright)

Keep it small and always-green: one spec covering signup/login -> the app's
single most important flow -> logout. Tag it `@smoke`; the `ci-cd` skill
runs it against deploys. Everything else stays at the integration layer,
which is faster and less flaky.

## What NOT to do

- Don't mock Prisma in integration tests: the schema, constraints, and
  extension behavior are exactly what you're verifying.
- Don't test RTK Query's internals (cache timing, tag plumbing); test what
  the user sees.
- Don't write E2E tests for every feature; the pyramid is
  integration-heavy, E2E-thin.
- Don't share mutable state between tests; every test builds what it needs.
