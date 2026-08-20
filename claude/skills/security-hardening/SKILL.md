---
name: security-hardening
description: >-
  Build-time security hardening rules for the house stack: Express 5 + TypeScript
  (ESM) + Prisma + PostgreSQL + Zod on Render/Heroku, Next.js App Router + React 19
  on Vercel, JWT auth in httpOnly cookies sent cross-origin with credentials
  "include". Apply AUTOMATICALLY and ALWAYS when creating an Express app or adding
  middleware, adding or changing an auth or public endpoint, handling uploads or
  webhooks or user-supplied HTML, configuring CORS, cookies, or headers, or before
  declaring any backend or frontend feature done. This is BUILD-TIME hardening
  (write the code securely the first time), distinct from the after-the-fact
  security-review command that audits a finished diff.
---

# Security Hardening (build-time)

Write it secure the first time. Every rule below has a one-line why; full,
copy-ready code for all of it lives in [reference/express-hardening.md](reference/express-hardening.md).
Read that file whenever you assemble an app, add a limiter, or wire uploads/webhooks.

## Express middleware order (exact, numbered)

Order is load-bearing: each layer protects the ones below it. Every step
reuses the project-scaffold skill's canonical modules (typed ENV, CustomError
subclasses, errorHandler, logger, request-id, queue) via `#*` imports;
middleware files live in `middlewares/` (plural) with kebab-case names
(`rate-limit.ts`, `origin-check.ts`, `error-handler.ts`).

1. `app.set("trust proxy", 1)` - Render/Heroku sit behind exactly one proxy hop; `1` makes `req.ip`, `secure` cookies, and rate-limit keying correct, while `true` would let clients spoof `X-Forwarded-For`.
2. `requestId` (the scaffold's `middlewares/request-id.ts`, pino-http) - first so everything downstream, including the errorHandler, logs with the correlation id; redaction lives in the scaffold's `utils/logger.ts` so secrets never reach logs.
3. `helmet(...)` - security headers on every response, including errors. The API returns JSON so CSP is mostly irrelevant there, but keep sensible defaults (`default-src 'none'`, `frame-ancestors 'none'`): it costs nothing and hardens any stray HTML output.
4. CORS from an ENV-driven allowlist (`ENV.CORS_ACCESS`, comma-separated) via an origin callback with `credentials: true` - NEVER a wildcard with credentials; browsers reject it and it would erase the origin boundary. Early so even rate-limited responses carry CORS headers.
5. Global rate limiter - 300 req / 15 min per IP on everything; over-limit requests go through `next(new TooManyRequestsError(...))` via the limiter's `handler` option, never hand-built JSON. The strict credential buckets attach later, inside the auth router (step 11).
6. `cookieParser()` - auth reads the JWT cookies, so parse before anything that authenticates.
7. Webhook raw-body routes at `/api/v1/webhooks/<provider>` with `express.raw()` - mounted BEFORE the JSON parser because signature verification needs the untouched raw body.
8. `express.json({ limit: "100kb" })` - a body cap kills memory-exhaustion payloads; raise the limit only on specific upload routes, never globally.
9. `originCheck` CSRF middleware - verifies Origin/Referer on every state-changing method (see below) before any route runs; rejects via `next(new ForbiddenError(...))`.
10. `/health` and `/ready` - at the root, unversioned (platform probes need stable paths; see api-contracts).
11. `/api/v1` routes - every app route mounts under the version prefix (auth at `/api/v1/auth`, etc.); authenticated and admin routers mounted separately from public ones. The strict authLimiter (10 req / 15 min) attaches PER CREDENTIAL ROUTE inside the auth router (`/login`, `/register`, `/password-reset/request`, `/password-reset/confirm`), NOT on the whole `/auth` mount: `/auth/me` and `/auth/refresh-token` are hit constantly by SSR and silent refresh and stay on the global limiter only.
12. 404 handler - `next(new NotFoundError(...))` so unknown paths flow through the same typed envelope; no hand-built JSON, no default HTML, no stack traces.
13. Central `errorHandler` (the scaffold's `middlewares/error-handler.ts`) LAST - the ONLY place errors become responses; it owns the `{ status: "error", message, code?, details? }` envelope and hides internals in production.

## CSRF for this stack (cookie auth, cross-origin)

Decision rule: use `sameSite: "lax"` on the access cookie (the refresh cookie
is `strict` and path-scoped per auth-conventions) PLUS strict Origin/Referer
verification on every POST/PUT/PATCH/DELETE, checked against the same CORS
allowlist. Cookie setting itself is owned by auth-conventions' CookieManager;
this skill only verifies the flags.

- Why it works: `lax` stops the cookie riding on cross-site subrequests and POSTs, and the Origin header is browser-controlled (attacker pages cannot forge it), so allowlist-checking it blocks any forged state change that slips through.
- Fail closed: a state-changing request with neither Origin nor Referer is rejected with a typed `ForbiddenError` (403); every real browser sends Origin on cross-origin unsafe requests.
- When you need more: if `sameSite: "none"` ever becomes required (e.g. embedded/iframe contexts), Origin checks alone are no longer sufficient defense-in-depth; add a double-submit token (random value in a readable cookie, echoed in a header, compared server-side).

## AuthZ checklist (deny by default)

- Authenticate at router level (`router.use(requireAuth)`), not per-handler: a forgotten handler must fail closed, not open.
- Authorize roles per route (`requireRole("ADMIN")`): authentication says who, never what.
- Ownership checks in services, not controllers: every fetch-by-id from a user-supplied id must assert `resource.userId === currentUser.id` (or role override), because IDOR is just a missing WHERE clause.
- Admin routers mounted separately from public routers: separate mount points make privilege boundaries greppable and mistakes visible.
- Deny by default: no route exists without an explicit decision that it is public.

## Input and output

- Zod at every boundary: body, query, params, headers you rely on, and webhook payloads (after signature check). Unvalidated query/params are the classic injection and type-confusion path.
- Sanitize user-supplied rich text with `sanitize-html` (allowlist config) BEFORE storing or rendering: stored XSS survives forever, so clean it at the door.
- Never `dangerouslySetInnerHTML` with unsanitized content; only ever pass it output of the sanitizer helper.
- Escape user content interpolated into emails (HTML-encode it): email clients render HTML and are a phishing amplifier.

## Uploads

- Validate MIME by magic bytes (`file-type` package on the buffer), never by extension or client-sent `Content-Type`: both are attacker-controlled.
- Cap size in multer `limits` (e.g. 5 MB) so one request cannot exhaust memory or disk.
- Randomize stored names (UUID + derived extension): user filenames enable path traversal and overwrites.
- Never execute or statically serve files from the upload path: an uploaded "image" that is really HTML/JS becomes XSS the moment you serve it from your origin.
- Treat the image-processing pipeline (e.g. sharp re-encode) as the trust boundary: only the re-encoded output is stored/served, so embedded payloads are destroyed.

## Webhooks

- Verify the provider signature over the RAW body; mount the route at `/api/v1/webhooks/<provider>` with `express.raw()` before the global JSON parser (see order item 7), because parsing then re-serializing changes bytes and breaks HMACs. A failed signature throws `UnauthorizedError`, never hand-built JSON.
- Compare digests with `crypto.timingSafeEqual`: string `===` leaks timing.
- Settle idempotently keyed on the provider event id (unique column or upsert): providers redeliver, and double-settling money or state is a real bug.
- Respond 2xx fast and enqueue real work through the scaffold's typed queue helper (`enqueue` from `#lib/queue.js`) with a `<feature>.<action>` job name (e.g. `payments.event-received`): slow handlers cause provider timeouts and redelivery storms.

## Secrets and PII

- Secrets only via the typed ENV module: never in code, logs, URLs, query strings, or error messages. URLs land in proxy logs and browser history.
- Redact in pino config (`authorization`, `cookie`, `set-cookie`, password/token/secret fields): logging is the most common accidental exfiltration channel.
- PII in this stack means: emails, names, phone numbers, addresses, IPs, auth identifiers, tokens, and anything Prisma stores about a person. Minimize: collect only what a feature needs, return only what a screen needs (Prisma `select`, never spread the whole model).
- Encrypt truly sensitive columns at rest (government ids, health/financial data) with app-level encryption, because a DB dump should not equal a breach.

## Dependencies

- Lockfile committed, always: unpinned transitive deps are a supply-chain door.
- `npm audit --audit-level=high` in CI, failing the build on high/critical.
- No packages with postinstall scripts from unknown publishers; check before adding (`npm pkg get scripts` on the dep, or use `--ignore-scripts` in CI).
- Pin Node LTS via `"engines"` in package.json so prod and dev run the same patched runtime.

## Frontend (Next.js on Vercel)

- Send a CSP from `next.config`/middleware: `script-src` with nonces (or `'self'` as the floor), `frame-ancestors 'none'`, `object-src 'none'`: this is the page-rendering origin, where CSP actually bites.
- No secrets in `NEXT_PUBLIC_*`: that prefix means "shipped to every browser".
- Sanitize before render, same helper policy as the API; never trust data just because your own API returned it.
- Avoid open redirects: validate any `callbackUrl`/`next` param against a relative-path or origin whitelist before redirecting, because open redirects launder phishing links under your domain.

## SSRF

Any server-side fetch of a user-provided URL must validate scheme (`https:` only)
and host against an explicit allowlist before fetching: otherwise users can make
your server call cloud metadata endpoints, localhost admin ports, or internal services.

## Self-audit checklist (run before calling any feature done)

Mechanically check each line against the diff:

- [ ] Middleware order matches the numbered list above; errorHandler is last; 404 (throwing NotFoundError) before it; app routes under /api/v1; /health and /ready at the root.
- [ ] `trust proxy` is `1`, not `true`.
- [ ] CORS origins come from `ENV.CORS_ACCESS`; no `*` anywhere near `credentials: true`.
- [ ] Global limiter active; the strict buckets sit per credential route inside the auth router (login, register, password-reset request/confirm), never on the whole `/auth` mount; limiter rejections flow through `TooManyRequestsError`.
- [ ] JSON body limit is 100kb globally; bigger limits only on named upload routes.
- [ ] Auth cookies set ONLY via auth-conventions' CookieManager: `httpOnly`, `secure`, access cookie `sameSite: "lax"` with `path: "/"`, refresh cookie `sameSite: "strict"` path-scoped to the refresh endpoint under `/api/v1/auth`.
- [ ] Every POST/PUT/PATCH/DELETE passes originCheck; no state change on GET.
- [ ] Router-level auth, per-route roles, ownership check in the service for every id-based fetch.
- [ ] Every new input (body/query/params/webhook) has a Zod schema.
- [ ] User HTML sanitized before store/render; no raw `dangerouslySetInnerHTML`; email content escaped.
- [ ] Uploads: magic-byte MIME check, size cap, random name, re-encoded, never served from upload dir.
- [ ] Webhooks: raw body at `/api/v1/webhooks/<provider>`, timing-safe signature check (UnauthorizedError on failure), idempotent by event id, fast 2xx, work enqueued via the typed queue helper with a `<feature>.<action>` name.
- [ ] No secret/PII in code, logs, URLs, or responses; pino redact paths cover new fields; Prisma queries `select` minimal fields.
- [ ] Lockfile updated and committed; new deps checked for postinstall scripts; CI audit still passes; engines pins Node LTS.
- [ ] Next app: CSP present, no new `NEXT_PUBLIC_` secrets, redirect targets whitelisted.
- [ ] Any server-side fetch of a user URL validates scheme + host allowlist.

If a box cannot be ticked, fix it now: this skill exists so the security-review
command finds nothing.
