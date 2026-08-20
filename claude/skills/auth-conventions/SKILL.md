---
name: auth-conventions
description: >-
  Authentication and authorization conventions for the house stack: Express 5 +
  TypeScript + Prisma + Zod APIs using JWT in httpOnly cookies, and Next.js App
  Router frontends with RTK Query. Apply AUTOMATICALLY and ALWAYS when writing,
  changing, or reviewing login or register endpoints, JWT or token code,
  password hashing or password reset, sessions, refresh flows, logout, email
  verification, RBAC / roles / permissions, protecting pages or routes,
  middleware.ts, auth cookies, or account lockout. Load this BEFORE designing
  any auth feature so the decisions below are applied instead of re-invented.
---

# Auth Conventions

Every default below is a decision already made. An unattended build follows them
instead of guessing, and a review flags any deviation.

## Scope and seams
- This skill owns auth design: tokens, sessions, password hashing, RBAC, page and route protection.
- security-hardening owns rate limiting, security headers, and CSRF mechanics. Lockout and backoff on auth endpoints are that skill's rate limits applied to these routes: do not hand-roll counters here.
- project-scaffold carries the canonical infra modules (typed ENV, CustomError subclasses, lib/prisma, queue). Reuse them, never fork them.
- backend-conventions owns layering (routes -> controllers -> services -> lib/prisma). Auth is a feature like any other: thin controllers, logic in services, kebab-case filenames.

## Reference files: read before writing code
- See reference/tokens.md before writing ANY token code: issueAuthTokens, CookieManager, the RefreshToken Prisma model, refresh rotation with reuse detection, logout, authenticateJWT + authorize.
- See reference/flows.md before register, login, password reset, or email verification: service sketches, Zod schema shapes, route wiring, typed pg-boss email queueing.
- See reference/nextjs-protection.md before touching middleware.ts, protected pages, role-gated layouts, or any SSR call to the API.

## Core defaults (state, do not debate)
- Hash passwords with argon2id: memoryCost 19456 KiB, timeCost 2, parallelism 1. Why: OWASP-recommended parameters that survive GPU cracking at acceptable latency. Fall back to bcrypt cost 12 only when the argon2 native module cannot be installed.
- Access token ~30m, refresh token ~7d, both read from ENV (ACCESS_TOKEN_EXPIRY, REFRESH_TOKEN_EXPIRY), never hardcoded. Why: a short access window caps replay damage; ENV keeps environments tunable without a deploy.
- Rotate refresh tokens on every use, with reuse detection. Store only a SHA-256 hash in the RefreshToken table (id, userId, tokenHash, expiresAt, revokedAt, replacedByTokenHash?). On refresh: verify, revoke the old row, issue a new one, in a transaction. A presented-but-already-revoked token means theft: revoke the whole family. Why: rotation makes a stolen refresh token single-use, and reuse detection turns replay into instant global revocation.
- Password reset and email verification use single-use tokens, stored hashed (SHA-256), with a TTL: 15-60 min for reset, 24h for verification. Why: a DB leak must not expose live magic links, and single-use kills forwarded or logged links.
- Never reveal whether an email exists where the flow allows it. Login and reset-request return uniform responses ("Invalid credentials" for both wrong email and wrong password; reset-request always claims the link was sent). Register signs the user in immediately, so a duplicate email surfaces as a generic ConflictError; the register rate limit blunts enumeration there. Why: any asymmetry is an enumeration oracle for credential stuffing.
- Register issues tokens immediately via issueAuthTokens (logged in right away, HTTP 201, same `{ message, data: <user> }` shape as login) AND enqueues the verification email; sensitive features may check emailVerifiedAt. There is no verify-first / 202 variant.
- Lockout and backoff on login, register, refresh-token, and reset endpoints come from the security-hardening skill's rate limits. Why: one shared mechanism, one place to tune it.

## Session semantics
- issueAuthTokens is the ONLY place tokens are signed and cookies set, always through CookieManager. Why: one choke point means expiries, flags, and payload shape can never drift between login, register, and refresh-token.
- Cookie flags: httpOnly always, secure in production, sameSite lax for the access cookie, sameSite strict AND path-scoped to /api/v1/auth (so refresh-token and logout both receive it, and nothing else does) for the refresh cookie, domain from ENV. Why: httpOnly blocks XSS token theft; path-scoping keeps the long-lived token off every other request.
- Logout revokes the presented refresh token in the DB and clears both cookies, and never fails. Why: revocation makes logout real on the server, not just cosmetic in the browser.
- Tokens live in cookies only. Never put a JWT in localStorage, sessionStorage, Redux state, or a response body the client is expected to store. Why: script-readable storage hands tokens to any XSS.

## RBAC and ownership
- Roles are a Prisma enum on User (e.g. USER, ADMIN); the role rides in the access token payload.
- Route-level: `authorize(...roles)` middleware runs AFTER authenticateJWT and throws ForbiddenError. Why: authentication and authorization are different failures (401 vs 403) and stack in that order.
- Ownership checks live in services (IDOR prevention): every query for a user-owned resource filters by the acting user (`where: { id, userId: actor.id }`) or fetches then verifies ownership and throws ForbiddenError. Never trust a client-supplied userId, ever, including "just for filtering". Why: route middleware cannot know who owns row 4783; only the service can.

## Next.js protection
- Protect pages with BOTH middleware.ts (fast redirect for unauthenticated users, with callbackUrl) AND server-side verification in layouts/pages via getSession(). Why: middleware sees only cookie presence and is bypassable; it is UX, not the security boundary.
- The Express API remains the enforcement point for every read and write. Page-level gating is convenience on top.
- Server Components call the cookie-authed API exactly one way: read `cookies()` from next/headers and forward them in the fetch Cookie header (see reference/nextjs-protection.md). SSR fetches carry no browser cookies on their own; nothing else works.
- Role-gated sections get a layout that calls getSession() and redirects on missing session or wrong role.
- Client-side, authenticated state lives in the auth slice, fed by the Mutex-guarded silent-refresh in the RTK Query base query. Never persist auth state to localStorage. Why: the httpOnly cookie is the truth; duplicating it in readable storage recreates the XSS surface the cookie removed.

## Pattern summaries
Route protection (backend), in this exact order:
```ts
router.get("/admin/reports", authenticateJWT, authorize("ADMIN"), asyncHandler(controller));
```
Ownership check in a service (never a client-supplied userId):
```ts
const doc = await prisma.document.findFirst({ where: { id, userId: actor.id } });
if (!doc) throw new NotFoundError("Document not found"); // 404, not 403: do not confirm existence
```
SSR call to the cookie-authed API (the only working recipe):
```ts
const cookieStore = await cookies(); // next/headers
const res = await fetch(`${PUBLIC_ENV.SERVER_URI}/api/v1/auth/me`, {
  headers: { Cookie: cookieStore.toString() },
  cache: "no-store",
});
```

## Self-audit checklist
Before finishing any auth work, verify every line:
- [ ] No em dash characters, kebab-case filenames, layering respected (routes -> controllers -> services).
- [ ] Passwords hashed with argon2id (19456 KiB / 2 / 1), never compared in plaintext, never logged.
- [ ] Tokens signed ONLY inside issueAuthTokens; cookies set ONLY via CookieManager; expiries from ENV.
- [ ] Refresh flow: hash stored (not the token), rotation in a transaction, reuse triggers family revocation.
- [ ] Reset and verification tokens: random bytes, SHA-256 stored, TTL enforced, marked used exactly once.
- [ ] Password change revokes ALL of the user's refresh tokens.
- [ ] Login and reset-request responses identical for existing vs unknown emails; register's duplicate-email ConflictError message stays generic.
- [ ] Errors thrown as CustomError subclasses (UnauthorizedError, ForbiddenError, BadRequestError, ConflictError) from `#utils/errors.js` in services; success responses use `{ message, data }` with the safe user object directly at the data root on login, register, refresh-token, and /auth/me; the error envelope `{ status: "error", message, code?, details? }` comes from the central handler, never hand-built.
- [ ] authorize(...) sits after authenticateJWT; services filter user-owned queries by the actor (no client-supplied userId trusted).
- [ ] Next.js: middleware.ts redirect AND server-side getSession() check both present; SSR API calls forward cookies(); no auth data in localStorage.
- [ ] Rate limiting on auth endpoints delegated to the security-hardening skill, not re-implemented.
