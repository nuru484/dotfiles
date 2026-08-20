# Reference: Auth Flows (Register, Login, Password Reset, Email Verification)

Read this before implementing any account flow. Sketches are service-level (the
layering skill owns the rest); wiring is shown in one or two lines per flow. Two
invariants recur: login and reset-request never reveal whether an email exists,
and anything sent by email is a single-use hashed token with a TTL. Every endpoint
that returns an identity (register, login, refresh-token, /auth/me) responds
`{ message, data: <safe user> }` with the user object directly at the data root,
matching the frontend contract `IAuthResponse = IApiResponse<IUser>`.

## Contents
- Zod schemas and validation wiring
- Prisma models: User and ActionToken
- Password hashing helpers
- Register
- Login
- Password reset (request + confirm)
- Email verification
- Email jobs (typed pg-boss queue)

## Zod schemas (src/validations/auth/auth-validation.ts)

```ts
import { z } from "zod";

const email = z.email().transform((v) => v.toLowerCase());
const newPassword = z.string().min(12).max(128);

export const registerSchema = z.object({
  email,
  password: newPassword,
  fullName: z.string().trim().min(1).max(100),
});

export const loginSchema = z.object({
  email,
  password: z.string().min(1), // no policy hints on login: do not leak the rules
});

export const passwordResetRequestSchema = z.object({ email });

export const passwordResetConfirmSchema = z.object({
  token: z.string().min(1),
  password: newPassword,
});

export const verifyEmailSchema = z.object({ token: z.string().min(1) });

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type PasswordResetConfirmInput = z.infer<typeof passwordResetConfirmSchema>;
```

Schemas are wired with the house validation middleware (see backend-conventions),
never a bespoke `validate(schema)` helper: `validationMiddleware.create(schema)`
validates req.body; use `validationMiddleware.custom(...)` when params or query
need validating as well.

## Prisma models: User and ActionToken

The canonical User shape. Every file in this skill (and the frontend SessionUser)
uses exactly these fields; the display name is `fullName`, there is no `name`.

```prisma
enum Role {
  USER
  ADMIN
}

model User {
  id              String    @id @default(cuid())
  fullName        String
  email           String    @unique
  passwordHash    String
  role            Role      @default(USER)
  emailVerifiedAt DateTime?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  deletedAt       DateTime?
}
```

One table for both reset and verification tokens: same lifecycle (hashed, TTL,
single-use), different TTLs at creation time.

```prisma
enum ActionTokenType {
  PASSWORD_RESET
  EMAIL_VERIFICATION
}

model ActionToken {
  id        String          @id @default(cuid())
  userId    String
  user      User            @relation(fields: [userId], references: [id], onDelete: Cascade)
  type      ActionTokenType
  tokenHash String          @unique
  expiresAt DateTime
  usedAt    DateTime?
  createdAt DateTime        @default(now())

  @@index([userId, type])
}
```

## Password hashing helpers (src/utils/password.ts)

argon2id with the OWASP parameters; import as `#utils/password.js`. The dummy hash
keeps login timing identical for unknown emails (see login below). Fall back to
bcrypt cost 12 only if the argon2 native module cannot be built on the target
platform.

```ts
import { randomUUID } from "node:crypto";
import { hash, verify, argon2id } from "argon2";

const ARGON2_OPTIONS = {
  type: argon2id,
  memoryCost: 19456, // KiB (19 MiB)
  timeCost: 2,
  parallelism: 1,
} as const;

export function hashPassword(plain: string): Promise<string> {
  return hash(plain, ARGON2_OPTIONS);
}

export function verifyPassword(digest: string, plain: string): Promise<boolean> {
  return verify(digest, plain);
}

let dummyHashPromise: Promise<string> | undefined;
export function dummyPasswordHash(): Promise<string> {
  dummyHashPromise ??= hash(randomUUID(), ARGON2_OPTIONS);
  return dummyHashPromise;
}
```

## Register

validate -> hash -> create user + verification token in one transaction -> issue
tokens -> enqueue verification email. Register logs the user in immediately:
issueAuthTokens runs at registration, the controller responds HTTP 201 with the
same `{ message, data: <user> }` shape as login, and verification happens in the
background; sensitive features check `user.emailVerifiedAt` instead of gating
login. The email goes through the typed pg-boss queue so a slow or down mail
provider cannot fail or delay registration. A duplicate email surfaces as a
generic ConflictError; the register rate limit (security-hardening skill) blunts
enumeration on this route.

```ts
// src/services/auth/register.service.ts
import { randomBytes } from "node:crypto";
import type { Response } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "#lib/prisma.js";
import { enqueue } from "#lib/queue.js";
import { ConflictError } from "#utils/errors.js";
import { hashPassword } from "#utils/password.js";
import { hashToken } from "#lib/hash-token.js";
import { issueAuthTokens } from "#services/auth/issue-auth-tokens.js";
import { toSafeUser, type SafeUser } from "#services/users/user-mapper.js";
import type { RegisterInput } from "#validations/auth/auth-validation.js";

const VERIFICATION_TTL_MS = 24 * 60 * 60 * 1000; // 24h

export async function register(res: Response, input: RegisterInput): Promise<SafeUser> {
  const passwordHash = await hashPassword(input.password);
  const rawToken = randomBytes(32).toString("base64url");

  let user;
  try {
    user = await prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: { email: input.email, fullName: input.fullName, passwordHash },
      });
      await tx.actionToken.create({
        data: {
          userId: created.id,
          type: "EMAIL_VERIFICATION",
          tokenHash: hashToken(rawToken),
          expiresAt: new Date(Date.now() + VERIFICATION_TTL_MS),
        },
      });
      return created;
    });
  } catch (err) {
    // The unique email constraint fired: duplicate registration.
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      throw new ConflictError("An account with this email already exists");
    }
    throw err;
  }

  await issueAuthTokens(res, user); // logged in right away; verification never gates login
  await enqueue("email.verification", { userId: user.id, email: user.email, token: rawToken });
  return toSafeUser(user); // never return passwordHash or token hashes
}
```

Wiring: `router.post("/register", validationMiddleware.create(registerSchema), asyncHandler(registerController));`
Controller: `res.status(HTTP_STATUS_CODES.CREATED).json({ message: "Registration successful", data: user });`
Same response shape as login: the user object sits directly at the data root.

## Login

One error, "Invalid credentials", for unknown email AND wrong password, and the
same argon2 work in both cases so response timing does not reveal which it was.
Tokens are issued only through issueAuthTokens (see reference/tokens.md).

```ts
// src/services/auth/login.service.ts
import type { Response } from "express";
import { prisma } from "#lib/prisma.js";
import { UnauthorizedError } from "#utils/errors.js";
import { verifyPassword, dummyPasswordHash } from "#utils/password.js";
import { issueAuthTokens } from "#services/auth/issue-auth-tokens.js";
import type { LoginInput } from "#validations/auth/auth-validation.js";
import { toSafeUser, type SafeUser } from "#services/users/user-mapper.js";

export async function login(res: Response, input: LoginInput): Promise<SafeUser> {
  const user = await prisma.user.findUnique({ where: { email: input.email } });

  const digest = user?.passwordHash ?? (await dummyPasswordHash());
  const passwordOk = await verifyPassword(digest, input.password);

  if (!user || !passwordOk) throw new UnauthorizedError("Invalid credentials");

  // Email verification never gates login (register signs the user in
  // immediately); sensitive features check user.emailVerifiedAt instead.
  await issueAuthTokens(res, user);
  return toSafeUser(user); // never return passwordHash or token hashes
}
```

Wiring: `router.post("/login", validationMiddleware.create(loginSchema), asyncHandler(loginController));`
Controller: `res.status(HTTP_STATUS_CODES.OK).json({ message: "Login successful", data: user });`
The user object sits directly at the data root, exactly like register,
refresh-token, and /auth/me (no `data: { user }` nesting).
Brute-force lockout on this route is the security-hardening skill's rate limiter.

## Password reset: request

Uniform response whether the email exists or not. A new request invalidates prior
unused reset tokens so only one live link exists at a time. TTL 30 min (stay within
the 15-60 min window).

```ts
// src/services/auth/password-reset.service.ts
import { randomBytes } from "node:crypto";
import { prisma } from "#lib/prisma.js";
import { enqueue } from "#lib/queue.js";
import { BadRequestError } from "#utils/errors.js";
import { hashPassword } from "#utils/password.js";
import { hashToken } from "#lib/hash-token.js";
import { revokeAllRefreshTokensForUser } from "#services/auth/refresh-token.service.js";
import type { PasswordResetConfirmInput } from "#validations/auth/auth-validation.js";

const RESET_TTL_MS = 30 * 60 * 1000; // 30 min

export async function requestPasswordReset(email: string): Promise<void> {
  const user = await prisma.user.findUnique({ where: { email } });
  if (!user) return; // uniform response; do not reveal existence

  const rawToken = randomBytes(32).toString("base64url");

  await prisma.$transaction(async (tx) => {
    await tx.actionToken.updateMany({
      where: { userId: user.id, type: "PASSWORD_RESET", usedAt: null },
      data: { usedAt: new Date() },
    });
    await tx.actionToken.create({
      data: {
        userId: user.id,
        type: "PASSWORD_RESET",
        tokenHash: hashToken(rawToken),
        expiresAt: new Date(Date.now() + RESET_TTL_MS),
      },
    });
  });

  await enqueue("email.password-reset", { userId: user.id, email: user.email, token: rawToken });
}
```

Wiring: `router.post("/password-reset/request", validationMiddleware.create(passwordResetRequestSchema), asyncHandler(...));`
Controller always: `{ message: "If that email is registered, a reset link has been sent.", data: null }`

## Password reset: confirm

Single-use enforced in the same transaction as the password update, and every
refresh token is revoked: a password change means the old credential may be
compromised, so every session dies.

```ts
export async function confirmPasswordReset(input: PasswordResetConfirmInput): Promise<void> {
  const tokenHash = hashToken(input.token);
  const passwordHash = await hashPassword(input.password);

  await prisma.$transaction(async (tx) => {
    const stored = await tx.actionToken.findUnique({ where: { tokenHash } });
    const valid =
      stored &&
      stored.type === "PASSWORD_RESET" &&
      !stored.usedAt &&
      stored.expiresAt > new Date();
    if (!valid) throw new BadRequestError("Invalid or expired reset token");

    await tx.actionToken.update({ where: { id: stored.id }, data: { usedAt: new Date() } });
    await tx.user.update({ where: { id: stored.userId }, data: { passwordHash } });
    await revokeAllRefreshTokensForUser(stored.userId, tx);
  });
}
```

Wiring: `router.post("/password-reset/confirm", validationMiddleware.create(passwordResetConfirmSchema), asyncHandler(...));`

## Email verification

Same single-use hashed-token lifecycle, 24h TTL set at creation (see register).

```ts
// src/services/auth/verify-email.service.ts
export async function verifyEmail(rawToken: string): Promise<void> {
  const tokenHash = hashToken(rawToken);

  await prisma.$transaction(async (tx) => {
    const stored = await tx.actionToken.findUnique({ where: { tokenHash } });
    const valid =
      stored &&
      stored.type === "EMAIL_VERIFICATION" &&
      !stored.usedAt &&
      stored.expiresAt > new Date();
    if (!valid) throw new BadRequestError("Invalid or expired verification token");

    await tx.actionToken.update({ where: { id: stored.id }, data: { usedAt: new Date() } });
    await tx.user.update({ where: { id: stored.userId }, data: { emailVerifiedAt: new Date() } });
  });
}
```

Wiring: `router.post("/verify-email", validationMiddleware.create(verifyEmailSchema), asyncHandler(...));`

## Email jobs (typed pg-boss queue)

Emails are enqueued through the typed queue module `#lib/queue.js` (see
project-scaffold), never raw `boss.send`. Add "email.verification" and
"email.password-reset" to the JobPayloads map and JOB_NAMES in lib/queue.ts
(pg-boss v10 requires every queue to be registered with createQueue at startup),
then call the typed enqueue helper:

```ts
await enqueue("email.verification", { userId: user.id, email: user.email, token: rawToken });
```

Workers live with the other queue workers; they receive the RAW token (it exists
only in the email link, never in the DB) and build the frontend URL from ENV. Type
the handler payload from the JobPayloads map, never a hand-rolled job type:

```ts
import { boss, type JobPayloads } from "#lib/queue.js";

await boss.work<JobPayloads["email.verification"]>("email.verification", async ([job]) => {
  await sendVerificationEmail(job.data.email, `${ENV.FRONTEND_URL}/verify-email?token=${job.data.token}`);
});
```
