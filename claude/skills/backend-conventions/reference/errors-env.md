# Reference: Errors, Env Config & Responses

Read this before adding an error type, an env variable, or a new response shape.

## Errors - one model, thrown from services, formatted centrally

`CustomError` carries context for logging and a consistent client contract:

```ts
export class CustomError extends Error {
  readonly status: number;
  readonly layer: string;
  readonly severity: ErrorSeverity;     // LOW | MEDIUM | HIGH | CRITICAL
  readonly timestamp: Date;
  readonly code?: string;
  readonly context?: Record<string, unknown>;
  constructor(status: number, message: string, options: { layer?: string; severity?: ErrorSeverity; code?: string; context?: Record<string, unknown> } = {}) {
    super(message);
    this.name = this.constructor.name;
    this.status = status;
    this.layer = options.layer ?? "unknown";
    this.severity = options.severity ?? ErrorSeverity.MEDIUM;
    this.timestamp = new Date();
    this.code = options.code;
    this.context = options.context;
    if (Error.captureStackTrace) Error.captureStackTrace(this, this.constructor);
  }
}
```

Use the **typed subclasses** - never throw a bare `Error`, never build error JSON
in a controller:

```
NotFoundError (404)   BadRequestError (400)   ValidationError (400)
UnauthorizedError(401) ForbiddenError (403)   ConflictError (409)
TooManyRequestsError(429) MethodNotAllowedError(405) InternalServerError(500)
```

```ts
if (!donor) throw new NotFoundError("Donor not found");
if (a.currency !== b.currency) throw new BadRequestError("Currency mismatch …");
```

The central `errorHandler` middleware then:
- converts Prisma errors first (`handlePrismaError`: P2002 → ConflictError,
  P2025 → NotFoundError, P2003 → BadRequestError),
- **redacts secrets** (`password`, `token`, `secret`, `key`, …) from logs,
- assigns an `errorId`, logs at a level chosen by `severity`,
- masks 500 messages in production, exposes `details` only for `VALIDATION_ERROR`,
- and emits exactly this client envelope (the contract in `api-contracts`):

```ts
// every error response, no exceptions:
{ status: "error", message: string, code?: string, details?: unknown }
```

Full canonical `errorHandler` source: `project-scaffold` →
`reference/backend-infra.md`. Copy it; never invent a variant.

Thrown/rejected errors must reach the handler. **Express 5 forwards rejected
promises from async handlers natively**, so new Express 5 code does not need a
wrapper; keep `asyncHandler` only in Express 4 repos or where the repo already
uses it consistently (consistency wins over removing it piecemeal):

```ts
export const asyncHandler = <T extends Request = Request>(
  fn: (req: T, res: Response, next: NextFunction) => Promise<void>,
) => (req: T, res: Response, next: NextFunction): Promise<void> =>
  Promise.resolve(fn(req, res, next)).catch(next);
```

## Env - typed, fail-fast, read via `ENV`

```ts
function envRequired(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required env variable: ${name}`);
  return v;
}
function envOptional(name: string): string | undefined {
  const v = process.env[name];
  return v?.length ? v : undefined;
}
function envNumber(name: string, defaultValue?: number): number { /* throws on NaN */ }
function envBool(name: string, defaultValue = false): boolean { /* 1/true/yes/on */ }

export const ENV = {
  PORT: envNumber("PORT", 4000), // house convention: API 4000, frontend 3000
  NODE_ENV: process.env.NODE_ENV ?? "development",
  DATABASE_URL: envRequired("DATABASE_URL"),
  ACCESS_TOKEN_SECRET: envRequired("ACCESS_TOKEN_SECRET"),
  ACCESS_TOKEN_EXPIRY: envOptional("ACCESS_TOKEN_EXPIRY") ?? "30m",
  // ...
} as const;
export default ENV;
```

Rules:
- Standard helpers: `envRequired / envOptional / envNumber / envBool`.
- The app imports `ENV` - **never** `process.env` outside `config/env.ts`.
- **Never hardcode a value that `ENV` already defines.** Example fix: sign tokens
  with `ENV.ACCESS_TOKEN_EXPIRY` / `ENV.REFRESH_TOKEN_EXPIRY`, not literal
  `"30m"` / `"7d"`.
- Add every new variable here so a misconfigured deploy fails at **startup**.

## Responses - one envelope everywhere

```ts
// Single resource
res.status(HTTP_STATUS_CODES.OK).json({ message: "Donation retrieved", data });

// List (always include meta; summary optional)
res.status(HTTP_STATUS_CODES.OK).json({
  message: "Donations retrieved",
  data,
  meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
  summary,
});
```

Every list endpoint uses the shared pagination helpers (canonical source in
`project-scaffold` → `reference/backend-infra.md`), never inline math:

```ts
// utils/paginate.ts - THE defaults: page 1, limit 10, limit cap 100
const { page, limit, skip } = parsePagination(query);   // validated + coerced
// ...findMany({ skip, take: limit }), count()...
res.status(HTTP_STATUS_CODES.OK).json({ message, data, meta: buildMeta(total, page, limit) });
```

Use `HTTP_STATUS_CODES` constants, not magic numbers.

## Sessions / cookies (structure, not security policy)

- `CookieManager` is the **one** place cookies are set/read (httpOnly, `secure`
  in production, `sameSite`, configurable domain).
- `issueAuthTokens` is the **one** place a session is established - sign tokens
  from `ENV.*_EXPIRY`, set cookies via `CookieManager`. Don't set auth cookies
  ad hoc elsewhere.

## TypeScript strictness

- No `any` - use `unknown` + type guards / `instanceof`.
- `import type { … }` for type-only imports.
- Prefer **Prisma-generated enums** over string literals (`PaymentStatus.SUCCESS`).
- `as const` for fixed config objects and shared `include` definitions.
