# Reference: Tokens, Cookies, and Session Lifecycle

Read this before writing any code that signs, verifies, stores, or revokes tokens.
All code assumes the house stack: Express 5, TypeScript ESM with `#*` subpath
imports, Prisma + PostgreSQL, typed `ENV`, `CustomError` subclasses, kebab-case
filenames. Success responses use `{ message, data }`, and every auth endpoint that
returns an identity (login, register, refresh-token, /auth/me) puts the safe user
object directly at the data root, matching the frontend contract
`IAuthResponse = IApiResponse<IUser>`. Errors are thrown and formatted by the
central error handler as `{ status: "error", message, code?, details? }`.

## Contents
- ENV additions
- Prisma model: RefreshToken
- src/lib/hash-token.ts
- src/lib/cookie-manager.ts
- src/services/auth/issue-auth-tokens.ts
- src/services/auth/refresh-token.service.ts (rotation + reuse detection)
- src/services/auth/logout.service.ts
- src/middleware/authenticate-jwt.ts and authorize
- Route and controller wiring

## ENV additions

Add to `config/env.ts` (JWT expiry strings for signing, millisecond TTLs for cookie
maxAge and DB expiresAt, so no ad hoc duration parsing anywhere else):

```ts
export const ENV = {
  // ...existing entries...
  ACCESS_TOKEN_SECRET: envRequired("ACCESS_TOKEN_SECRET"),
  REFRESH_TOKEN_SECRET: envRequired("REFRESH_TOKEN_SECRET"),
  ACCESS_TOKEN_EXPIRY: envOptional("ACCESS_TOKEN_EXPIRY") ?? "30m",
  REFRESH_TOKEN_EXPIRY: envOptional("REFRESH_TOKEN_EXPIRY") ?? "7d",
  ACCESS_TOKEN_TTL_MS: envNumber("ACCESS_TOKEN_TTL_MS", 30 * 60 * 1000),
  REFRESH_TOKEN_TTL_MS: envNumber("REFRESH_TOKEN_TTL_MS", 7 * 24 * 60 * 60 * 1000),
  COOKIE_DOMAIN: envOptional("COOKIE_DOMAIN"),
} as const;
```

Use two secrets so a leaked access secret cannot mint refresh tokens.

## Prisma model: RefreshToken

Store only the SHA-256 hash: a DB dump must not contain usable sessions.
`replacedByTokenHash` links each rotation to its successor so a reuse event can
revoke the whole family (one family per device/login).

```prisma
model RefreshToken {
  id                  String    @id @default(cuid())
  userId              String
  user                User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  tokenHash           String    @unique
  expiresAt           DateTime
  revokedAt           DateTime?
  replacedByTokenHash String?
  createdAt           DateTime  @default(now())

  @@index([userId])
}
```

## src/lib/hash-token.ts

SHA-256, not argon2, for tokens: the input is already 256 bits of entropy, so a
fast hash is safe and keeps lookups indexable.

```ts
import { createHash } from "node:crypto";

export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
```

## src/lib/cookie-manager.ts

The single place cookie names, flags, and paths are defined. The refresh cookie is
sameSite strict and path-scoped to `/api/v1/auth` so the long-lived token travels
to routes beneath that path, including POST /api/v1/auth/refresh-token (rotation)
and POST /api/v1/auth/logout (server-side revocation). Cookie paths limit sending but are not authorization boundaries.
clearCookie must repeat the same options or browsers will not match the cookie.

```ts
import type { CookieOptions, Request, Response } from "express";
import { ENV } from "#config/env.js";

export const ACCESS_COOKIE = "access_token";
export const REFRESH_COOKIE = "refresh_token";
// Scoped to the auth router, NOT a single endpoint: both /api/v1/auth/refresh-token
// and /api/v1/auth/logout need the refresh cookie; other routes under this path also receive it.
export const REFRESH_COOKIE_PATH = "/api/v1/auth";

export class CookieManager {
  private static base(): CookieOptions {
    return {
      httpOnly: true,
      secure: ENV.NODE_ENV === "production",
      sameSite: "lax",
      domain: ENV.COOKIE_DOMAIN,
      path: "/",
    };
  }

  private static refreshOptions(): CookieOptions {
    return { ...this.base(), sameSite: "strict", path: REFRESH_COOKIE_PATH };
  }

  static setAuthCookies(res: Response, accessToken: string, refreshToken: string): void {
    res.cookie(ACCESS_COOKIE, accessToken, { ...this.base(), maxAge: ENV.ACCESS_TOKEN_TTL_MS });
    res.cookie(REFRESH_COOKIE, refreshToken, {
      ...this.refreshOptions(),
      maxAge: ENV.REFRESH_TOKEN_TTL_MS,
    });
  }

  static clearAuthCookies(res: Response): void {
    res.clearCookie(ACCESS_COOKIE, this.base());
    res.clearCookie(REFRESH_COOKIE, this.refreshOptions());
  }

  static getAccessToken(req: Request): string | undefined {
    return req.cookies?.[ACCESS_COOKIE];
  }

  static getRefreshToken(req: Request): string | undefined {
    return req.cookies?.[REFRESH_COOKIE];
  }
}
```

## src/services/auth/issue-auth-tokens.ts

This module separates signing/persistence from HTTP cookie emission.
createAndPersistTokens accepts the transaction client and returns token material;
issueAuthTokens is the login/register wrapper that commits before setting cookies.
Use the project's generated Prisma imports and actual transaction-client types.

```ts
import { randomUUID } from "node:crypto";
import type { Response } from "express";
import { sign, type SignOptions } from "jsonwebtoken";
import type { Role } from "@prisma/client";
import { prisma, type TransactionClient } from "#lib/prisma.js";
import { ENV } from "#config/env.js";
import { CookieManager } from "#lib/cookie-manager.js";
import { hashToken } from "#lib/hash-token.js";

export interface AuthTokenUser {
  id: string;
  role: Role;
}

export interface IssuedTokens {
  accessToken: string;
  refreshToken: string;
  refreshTokenHash: string;
}

export async function createAndPersistTokens(
  user: AuthTokenUser,
  tx: TransactionClient | typeof prisma = prisma,
): Promise<IssuedTokens> {
  const accessToken = sign({ sub: user.id, role: user.role }, ENV.ACCESS_TOKEN_SECRET, {
    expiresIn: ENV.ACCESS_TOKEN_EXPIRY as SignOptions["expiresIn"],
  });

  // jti makes every refresh token unique even for the same user and second,
  // so the SHA-256 hash is a safe unique lookup key.
  const refreshToken = sign({ sub: user.id, jti: randomUUID() }, ENV.REFRESH_TOKEN_SECRET, {
    expiresIn: ENV.REFRESH_TOKEN_EXPIRY as SignOptions["expiresIn"],
  });

  const refreshTokenHash = hashToken(refreshToken);

  await tx.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: refreshTokenHash,
      expiresAt: new Date(Date.now() + ENV.REFRESH_TOKEN_TTL_MS),
    },
  });

  return { accessToken, refreshToken, refreshTokenHash };
}
```

`createAndPersistTokens(user, tx)` signs and stores tokens without touching HTTP.
For login/register, the convenience helper `issueAuthTokens(res, user)` commits
that work first, then uses CookieManager.setAuthCookies. Do not accept an external
transaction in a helper that writes response headers.

```ts
export async function issueAuthTokens(res: Response, user: AuthTokenUser): Promise<IssuedTokens> {
  const issued = await prisma.$transaction((tx) => createAndPersistTokens(user, tx));
  CookieManager.setAuthCookies(res, issued.accessToken, issued.refreshToken);
  return issued;
}
```

## src/services/auth/refresh-token.service.ts

Rotation needs a transaction that serializes competing use of the same token.
Return a rejection outcome from the callback when revocation must commit, then
throw outside it. A throw inside the callback rolls revocation back. Set cookies
only after the database commits. Bound retries of serialization conflicts and do
not perform HTTP or network side effects inside a retried callback.

The code below specifies the transaction body; wire it through the project's
bounded serializable-transaction retry helper (retry only recognized serialization
conflicts, not authentication failures). Check the installed Prisma error codes and
exercise it against PostgreSQL. A same-tab mutex does not prevent cross-tab races.
Choose and test a documented concurrent-refresh policy; strict reuse revocation can
invalidate a legitimate session when two tabs race.

```ts
import type { Request, Response } from "express";
import { verify } from "jsonwebtoken";
import { prisma, type TransactionClient } from "#lib/prisma.js";
import { ENV } from "#config/env.js";
import { UnauthorizedError } from "#utils/errors.js";
import { CookieManager } from "#lib/cookie-manager.js";
import { hashToken } from "#lib/hash-token.js";
import { createAndPersistTokens, type IssuedTokens } from "#services/auth/issue-auth-tokens.js";
import { toSafeUser, type SafeUser } from "#services/users/user-mapper.js";

type RotationOutcome =
  | { ok: false }
  | { ok: true; user: SafeUser; issued: IssuedTokens };

// Called by a bounded serializable transaction runner. No HTTP side effects.
export async function rotateInTransaction(
  tx: TransactionClient, presentedHash: string,
): Promise<RotationOutcome> {
  const stored = await tx.refreshToken.findUnique({ where: { tokenHash: presentedHash } });
  if (!stored) return { ok: false };
  if (stored.revokedAt) {
    await revokeTokenFamily(tx, stored.tokenHash);
    return { ok: false }; // returning allows family revocation to COMMIT
  }
  if (stored.expiresAt <= new Date()) return { ok: false };
  const user = await tx.user.findUnique({ where: { id: stored.userId } });
  if (!user) return { ok: false };
  // Apply the project's disabled-account/session-version checks here too.
  const claimed = await tx.refreshToken.updateMany({
    where: { id: stored.id, revokedAt: null, expiresAt: { gt: new Date() } },
    data: { revokedAt: new Date() },
  });
  if (claimed.count !== 1) return { ok: false };
  const issued = await createAndPersistTokens(user, tx);
  await tx.refreshToken.update({
    where: { id: stored.id }, data: { replacedByTokenHash: issued.refreshTokenHash },
  });
  return { ok: true, user: toSafeUser(user), issued };
}

// Request-level sequence (adapt the runner to the repository):
// 1. Read cookie and verify signature, allowed algorithm, expiry and expected claims.
// 2. Hash it, then run rotateInTransaction in a SERIALIZABLE transaction with
//    bounded retries for serialization conflicts.
// 3. Await commit. If outcome.ok is false, throw UnauthorizedError outside it.
// 4. Set cookies from outcome.issued and return outcome.user.

// Walk the rotation chain forward and revoke every descendant. This kills the
// stolen line (one device/login) without logging the user out everywhere else.
// If in doubt, revokeAllRefreshTokensForUser is the blunter, equally safe choice.
async function revokeTokenFamily(tx: TransactionClient, startHash: string): Promise<void> {
  const seen = new Set<string>();
  let hash: string | null = startHash;

  while (hash && !seen.has(hash)) {
    seen.add(hash);
    const row = await tx.refreshToken.findUnique({ where: { tokenHash: hash } });
    if (!row) return;
    if (!row.revokedAt) {
      await tx.refreshToken.update({ where: { id: row.id }, data: { revokedAt: new Date() } });
    }
    hash = row.replacedByTokenHash;
  }
}

// Used by password change/reset: a changed credential invalidates every session.
export async function revokeAllRefreshTokensForUser(
  userId: string,
  tx: TransactionClient | typeof prisma = prisma,
): Promise<void> {
  await tx.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
```

## src/services/auth/logout.service.ts

Logout is idempotent for missing/invalid tokens. Clear cookies even when database
revocation fails, but report that server revocation failed rather than claiming it
succeeded. Clearing cookies alone does not invalidate an already issued JWT.

```ts
import type { Request, Response } from "express";
import { prisma } from "#lib/prisma.js";
import { CookieManager } from "#lib/cookie-manager.js";
import { hashToken } from "#lib/hash-token.js";

export async function logout(req: Request, res: Response): Promise<void> {
  const presented = CookieManager.getRefreshToken(req);

  try {
    if (presented) {
      await prisma.refreshToken.updateMany({
        where: { tokenHash: hashToken(presented), revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }
  } finally {
    CookieManager.clearAuthCookies(res);
  }
}
```

## src/middleware/authenticate-jwt.ts

Verifies the access token from the cookie and attaches the actor. `authorize` runs
after it and only checks role: 401 means "who are you", 403 means "not for you".

```ts
import type { NextFunction, Request, Response } from "express";
import { verify, type JwtPayload } from "jsonwebtoken";
import type { Role } from "@prisma/client";
import { ENV } from "#config/env.js";
import { UnauthorizedError, ForbiddenError } from "#utils/errors.js";
import { CookieManager } from "#lib/cookie-manager.js";

export interface AuthenticatedRequest extends Request {
  user?: { id: string; role: Role };
}

export function authenticateJWT(req: AuthenticatedRequest, _res: Response, next: NextFunction): void {
  const token = CookieManager.getAccessToken(req);
  if (!token) throw new UnauthorizedError("Authentication required");

  let payload: JwtPayload & { role: Role };
  try {
    payload = verify(token, ENV.ACCESS_TOKEN_SECRET) as JwtPayload & { role: Role };
  } catch {
    throw new UnauthorizedError("Authentication required");
  }

  // next() stays outside the try so a downstream throw is not swallowed
  // and mislabeled as an auth failure.
  req.user = { id: payload.sub as string, role: payload.role };
  next();
}

export function authorize(...roles: Role[]) {
  return (req: AuthenticatedRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) throw new UnauthorizedError("Authentication required");
    if (!roles.includes(req.user.role)) throw new ForbiddenError("Insufficient permissions");
    next();
  };
}
```

## Route and controller wiring

The auth router mounts at `/api/v1/auth`, so the refresh cookie (path
`/api/v1/auth`) accompanies both POST /api/v1/auth/refresh-token and
POST /api/v1/auth/logout. The endpoint name is `refresh-token`: the frontend RTK
Query base query calls POST `auth/refresh-token`, never `/refresh`.

```ts
// src/routes/auth.routes.ts
router.post("/refresh-token", asyncHandler(refreshController));
router.post("/logout", asyncHandler(logoutController));
router.get("/me", authenticateJWT, asyncHandler(meController));

// src/controllers/auth.controller.ts
export const refreshController = async (req: Request, res: Response): Promise<void> => {
  const user = await rotateRefreshToken(req, res);
  res.status(HTTP_STATUS_CODES.OK).json({ message: "Session refreshed", data: user });
};

export const logoutController = async (req: Request, res: Response): Promise<void> => {
  await logout(req, res);
  res.status(HTTP_STATUS_CODES.OK).json({ message: "Logged out", data: null });
};

export const meController = async (req: AuthenticatedRequest, res: Response): Promise<void> => {
  const user = await getCurrentUser(req.user!.id); // service returns the safe user
  res.status(HTTP_STATUS_CODES.OK).json({ message: "Authenticated user", data: user });
};
```

Like login and register, refresh-token and /auth/me put the safe user object
directly at the data root; only logout responds with `data: null`.

The controller never signs tokens, never touches cookies directly, and never builds
error JSON: services throw, the central handler formats.

## Required behavior checks

Use a real isolated database for concurrent rotation and rollback checks. Verify:
- Two concurrent uses cannot mint two live successors under the selected policy.
- Reuse revocation persists after the request returns an authentication error.
- A failed commit emits no replacement cookies.
- Expired/malformed tokens are rejected; disabled accounts follow project policy.
- Revoking refresh tokens does not immediately revoke stateless access tokens;
  sensitive access needs a current-account/session-version check if immediate revocation is required.
- Missing-token logout is idempotent; database failure still clears cookies and is reported.

Cookie topology matters: same-site subdomains and cross-site hosting are different.
SameSite=Lax/Strict cookies will not authenticate cross-site fetches. Cross-site
cookies require Secure and SameSite=None plus CSRF defenses, and may still be blocked
by browser policy. Host-only API cookies are not visible to Next.js SSR on a different
host; choose compatible domains or an explicit same-origin/session architecture.

## Replay retention and expiry policy

The default here rejects expired JWTs before rotation and does not use an expired
ancestor alone to trigger family revocation. If the product requires that stronger
policy, verify the token signature/claims while handling expiry explicitly before
looking up the retained hash; never rotate an expired token. Document that decision.
Keep revoked chain records while a live descendant can exist; pruning a middle link
breaks traversal. A session-family identifier with indexed bulk revocation can be
simpler than a chain, but is a schema decision that needs migration and race tests.
