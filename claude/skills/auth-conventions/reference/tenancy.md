# Reference: Multi-Tenancy (Organizations, Memberships, Invitations)

Single-tenant is the default (see app-blueprint's decision table). The MOMENT a
spec says teams, workspaces, organizations, or "invite members", this file
governs and the models below are the blessed shape. Never bolt org roles onto
the global `User.role` enum: that enum is platform-level only, and forking it
per feature is how tenant leaks start. All code assumes the house stack:
Express 5, TypeScript ESM with `#*` subpath imports, Prisma + PostgreSQL,
typed `ENV`, `CustomError` subclasses from `#utils/errors.js`, kebab-case
filenames, success envelope `{ message, data }`, errors formatted only by the
central errorHandler.

## Contents
- Two role systems with different jobs
- Blessed Prisma models: Organization, Membership, Invitation
- Resolving the active org: the path-param convention
- src/middlewares/require-membership.ts
- Route wiring (mergeParams is load-bearing)
- THE SCOPING LAW: orgId on every tenant-owned query
- Service signature convention: ctx first
- The cross-tenant test rule
- Organization creation
- Invitation flow (create, email job, accept)
- Platform-admin surface (/api/v1/admin)

## Two role systems with different jobs

This is a split, not a fork. State it in PLAN.md and never blur it:

- **`User.role` (global enum)** stays ONLY for platform-level roles:
  `PLATFORM_ADMIN` for the SaaS owner's cross-tenant support surface, `USER`
  for everyone else. In a multi-tenant app there is no global `ADMIN`; the
  single-tenant enum's `ADMIN` value becomes `PLATFORM_ADMIN` with a strictly
  platform-operations meaning.
- **`Membership.role` (`MemberRole` enum)** carries ALL per-org authority:
  what a user may do inside one organization. A user can be OWNER of org A and
  MEMBER of org B; the global role says nothing about either.

The access token payload does not change: it carries `userId` + the global
role only (`{ sub, role }`, signed by issueAuthTokens as in
reference/tokens.md). Org authority is never in the token. *Why:* memberships
change (invites, removals, role changes) independently of sessions; baking
them into a 30-minute token creates stale-permission windows and fat payloads.
The DB row is the authority, loaded per request by requireMembership below.

## Blessed Prisma models

```prisma
enum MemberRole {
  OWNER
  ADMIN
  MEMBER
}

model Organization {
  id        String    @id @default(cuid())
  name      String
  slug      String    @unique
  createdAt DateTime  @default(now())
  updatedAt DateTime  @updatedAt
  deletedAt DateTime?

  memberships Membership[]
  invitations Invitation[]
}

model Membership {
  id           String       @id @default(cuid())
  userId       String
  user         User         @relation(fields: [userId], references: [id], onDelete: Cascade)
  orgId        String
  organization Organization @relation(fields: [orgId], references: [id], onDelete: Cascade)
  role         MemberRole   @default(MEMBER)
  createdAt    DateTime     @default(now())
  updatedAt    DateTime     @updatedAt

  @@unique([userId, orgId])
  @@index([orgId])
}

model Invitation {
  id           String       @id @default(cuid())
  orgId        String
  organization Organization @relation(fields: [orgId], references: [id], onDelete: Cascade)
  email        String
  role         MemberRole   @default(MEMBER)
  tokenHash    String       @unique
  expiresAt    DateTime
  acceptedAt   DateTime?
  invitedById  String
  invitedBy    User         @relation("InvitationsSent", fields: [invitedById], references: [id])
  createdAt    DateTime     @default(now())
  updatedAt    DateTime     @updatedAt

  @@unique([orgId, email])
}
```

And the global enum becomes:

```prisma
enum Role {
  USER
  PLATFORM_ADMIN
}
```

Notes:
- Membership deliberately has NO `deletedAt`: it is a permission edge, not
  domain data. Removing a member hard-deletes the row (the user and anything
  they authored remain); keeping revoked permission rows around invites
  resurrection bugs. Organization keeps `deletedAt` like every mutable model.
- `@@unique([orgId, email])` on Invitation means re-inviting upserts: one live
  invitation per address per org, and a re-invite replaces the old token.
- `tokenHash` follows the house token law (reference/tokens.md): random bytes,
  SHA-256 stored, raw token exists only in the email link, single-use, TTL.

## Resolving the active org: the path-param convention

The active org is resolved per request from the URL:
`/api/v1/orgs/:orgId/...`. This is the convention; an `x-org-id` header is the
rejected alternative. *Why the path param wins:* it is cacheable (the URL is
the cache key), loggable (every access log line and errorHandler line already
carries the path, so tenant context is greppable for free), and impossible to
forget (a route under the org router simply cannot be built without deciding
its org, whereas a header is one forgotten line away from an unscoped query).

Endpoints that are user-owned rather than tenant-owned (the user's own orgs
list, invitation accept, /auth/*) stay outside `/orgs/:orgId`.

## src/middlewares/require-membership.ts

Runs AFTER authenticateJWT. Loads the actor's Membership for the org in the
path and throws ForbiddenError when absent, when the org is soft-deleted, or
when the member's role is below the required one. Roles are ranked so
`requireMembership("ADMIN")` admits OWNER too.

```ts
import type { NextFunction, Response } from "express";
import type { MemberRole } from "@prisma/client";
import { prisma } from "#lib/prisma.js";
import { ForbiddenError, UnauthorizedError } from "#utils/errors.js";
import type { AuthenticatedRequest } from "#middlewares/authenticate-jwt.js";

const ROLE_RANK: Record<MemberRole, number> = { MEMBER: 1, ADMIN: 2, OWNER: 3 };

export interface OrgRequest extends AuthenticatedRequest {
  membership?: {
    id: string;
    userId: string;
    orgId: string;
    role: MemberRole;
  };
}

export function requireMembership(minRole: MemberRole = "MEMBER") {
  return async (req: OrgRequest, _res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user) throw new UnauthorizedError("Authentication required");
      const { orgId } = req.params;
      if (!orgId) throw new ForbiddenError("Organization context required");

      // A stricter check later in the chain reuses the row already loaded by
      // the router-level requireMembership(): one DB hit per request.
      if (req.membership?.orgId === orgId) {
        if (ROLE_RANK[req.membership.role] < ROLE_RANK[minRole]) {
          throw new ForbiddenError("Insufficient organization role");
        }
        return next();
      }

      // findUnique is the deliberate unscoped seam (Membership has no
      // deletedAt), so the org's own soft delete is checked explicitly.
      const membership = await prisma.membership.findUnique({
        where: { userId_orgId: { userId: req.user.id, orgId } },
        include: { organization: { select: { deletedAt: true } } },
      });

      // Nonexistent org, deleted org, and non-membership all look identical
      // from outside: 403 either way, so probing org ids confirms nothing.
      if (!membership || membership.organization.deletedAt) {
        throw new ForbiddenError("You are not a member of this organization");
      }
      if (ROLE_RANK[membership.role] < ROLE_RANK[minRole]) {
        throw new ForbiddenError("Insufficient organization role");
      }

      req.membership = {
        id: membership.id,
        userId: membership.userId,
        orgId: membership.orgId,
        role: membership.role,
      };
      next();
    } catch (err) {
      next(err);
    }
  };
}
```

## Route wiring (mergeParams is load-bearing)

Without `mergeParams: true`, `req.params.orgId` is invisible inside a nested
router and requireMembership silently sees `undefined`. This is the classic
footgun; the fail-closed guard in the middleware catches it, but wire it right:

```ts
// src/routes/orgs/org-routes.ts - user-owned org endpoints (no :orgId)
const orgRouter = Router();
orgRouter.use(authenticateJWT);
orgRouter.post("/", validationMiddleware.create(createOrgSchema), asyncHandler(createOrgController));
orgRouter.get("/", asyncHandler(listMyOrgsController)); // the actor's memberships

// src/routes/orgs/org-scoped-routes.ts - everything under /orgs/:orgId
const orgScopedRouter = Router({ mergeParams: true });
orgScopedRouter.use(authenticateJWT, requireMembership()); // deny by default: member floor
orgScopedRouter.post(
  "/invitations",
  requireMembership("ADMIN"), // reuses the loaded row; no second query
  inviteLimiter, // invites send email: throttled like password reset (security-hardening owns limiter mechanics)
  validationMiddleware.create(createInvitationSchema),
  asyncHandler(createInvitationController),
);
orgScopedRouter.use("/projects", projectRouter); // every tenant-owned feature mounts here

// src/routes/index.ts (excerpt)
router.use("/orgs", orgRouter);
router.use("/orgs/:orgId", orgScopedRouter);
router.use("/invitations", invitationRouter); // accept lives OUTSIDE :orgId: the acceptor is not a member yet
router.use("/admin", adminRouter); // platform-admin surface, see below
```

## THE SCOPING LAW

Every tenant-owned model carries `orgId` (indexed, `@@index([orgId])`). Every
service query for tenant-owned data filters by the membership-verified orgId
from the request context, NEVER a client-supplied body value. Deletes and
updates use a `{ id, orgId }` compound where. *Why:* the id alone is the IDOR
hole with a tenant multiplier; the compound where makes a cross-tenant id
behave exactly like a nonexistent one (404, confirming nothing).

```prisma
model Project {
  id           String       @id @default(cuid())
  orgId        String
  organization Organization @relation(fields: [orgId], references: [id])
  name         String
  createdAt    DateTime     @default(now())
  updatedAt    DateTime     @updatedAt
  deletedAt    DateTime?

  @@index([orgId])
}
```

```ts
// Read: filter by ctx.orgId, 404 on miss (never 403: do not confirm existence)
export async function getProject(ctx: OrgContext, id: string): Promise<Project> {
  const project = await prisma.project.findFirst({ where: { id, orgId: ctx.orgId } });
  if (!project) throw new NotFoundError("Project not found");
  return project;
}

// Mutate: atomic guarded updateMany with the compound where, assert the count
export async function deleteProject(ctx: OrgContext, id: string): Promise<void> {
  const { count } = await prisma.project.updateMany({
    where: { id, orgId: ctx.orgId, deletedAt: null }, // soft delete, house style
    data: { deletedAt: new Date() },
  });
  if (count === 0) throw new NotFoundError("Project not found");
}
```

List queries add `orgId: ctx.orgId` to the same `where` used by `findMany`
and `count`. There are no exceptions inside tenant features: a query without
`ctx.orgId` in its where is a bug even when "the ids are unguessable".

## Service signature convention: ctx first

Tenant-owned services take the org context as their FIRST parameter, typed,
built only from requireMembership's verified output:

```ts
// src/types/org.types.ts
import type { MemberRole } from "@prisma/client";

export interface OrgActor {
  id: string;
  memberRole: MemberRole;
}

export interface OrgContext {
  /** Verified by requireMembership from the :orgId path param. NEVER from the body. */
  orgId: string;
  actor: OrgActor;
}
```

```ts
// src/utils/org-context.ts - the one place controllers build the ctx
import type { OrgRequest } from "#middlewares/require-membership.js";
import type { OrgContext } from "#types/org.types.js";

export function orgContextFrom(req: OrgRequest): OrgContext {
  const membership = req.membership!; // requireMembership ran before any controller
  return {
    orgId: membership.orgId,
    actor: { id: membership.userId, memberRole: membership.role },
  };
}
```

Controllers stay thin: `const ctx = orgContextFrom(req);` then
`await updateProject(ctx, input)`. A service that needs to distinguish
member-level authority checks it from `ctx.actor.memberRole` and throws
ForbiddenError; it never re-queries the membership.

## The cross-tenant test rule

Every tenant-owned feature ships AT LEAST one test asserting org B cannot read
or mutate org A's rows. This is part of the tdd skill's always-test floor, not
an optional extra. Use the harness helpers from tdd/harness.md (`resetDb`,
`createTestUser`, `authCookieFor`) plus one org factory:

```ts
// tests/helpers/orgs.ts
import { randomUUID } from "node:crypto";
import { prisma } from "#lib/prisma.js";
import { createTestUser } from "./auth.js";

export async function createTestOrg(name = "Test Org") {
  const owner = await createTestUser();
  const org = await prisma.organization.create({
    data: {
      name,
      slug: `test-org-${randomUUID().slice(0, 8)}`,
      memberships: { create: { userId: owner.id, role: "OWNER" } },
    },
  });
  return { org, owner };
}
```

```ts
test("org B owner cannot read org A's project", async () => {
  const { org: orgA } = await createTestOrg("Org A");
  const project = await createTestProject({ orgId: orgA.id });
  const { owner: ownerB } = await createTestOrg("Org B");

  const res = await request(app)
    .get(`/api/v1/orgs/${orgA.id}/projects/${project.id}`)
    .set("Cookie", await authCookieFor(ownerB));

  expect(res.status).toBe(403); // requireMembership rejects before the service runs
  expect(res.body.status).toBe("error");
});
```

Also test the deeper layer at least once per app: a member of org A requesting
org A's URL with org B's resource id gets a 404 (the compound where held).

## Organization creation

Creating an org and its OWNER membership is one atomic nested create; slugs
are derived from the name with a random suffix on collision:

```ts
// src/services/orgs/org.service.ts
export async function createOrganization(actorId: string, input: CreateOrgInput) {
  return prisma.organization.create({
    data: {
      name: input.name,
      slug: await uniqueSlug(input.name),
      memberships: { create: { userId: actorId, role: "OWNER" } }, // atomic with the org row
    },
  });
}
```

## Invitation flow

create -> hashed single-use token -> email via the typed queue -> accept ->
Membership created in a transaction. Uniform responses throughout: the invite
endpoint NEVER reveals whether an email already belongs to a member (the same
enumeration law as login and reset-request in reference/flows.md).

Zod schemas (`src/validations/orgs/org-validation.ts`):

```ts
export const createInvitationSchema = z.object({
  email: z.email().transform((v) => v.toLowerCase()),
  role: z.enum(["ADMIN", "MEMBER"]), // OWNER is never invitable; ownership transfer is a separate deliberate flow
});

export const acceptInvitationSchema = z.object({ token: z.string().min(1) });
```

Create (service): existing members are a silent no-op so the response stays
uniform; re-invites replace the token via the `@@unique([orgId, email])` upsert.

```ts
// src/services/orgs/invitation.service.ts
const INVITE_TTL_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

export async function createInvitation(ctx: OrgContext, input: CreateInvitationInput): Promise<void> {
  const alreadyMember = await prisma.membership.findFirst({
    where: { orgId: ctx.orgId, user: { email: input.email } },
    select: { id: true },
  });
  if (alreadyMember) return; // uniform response; do not reveal membership

  const rawToken = randomBytes(32).toString("base64url");
  const data = {
    role: input.role,
    tokenHash: hashToken(rawToken), // SHA-256; the raw token exists only in the email link
    expiresAt: new Date(Date.now() + INVITE_TTL_MS),
    acceptedAt: null,
    invitedById: ctx.actor.id,
  };

  await prisma.invitation.upsert({
    where: { orgId_email: { orgId: ctx.orgId, email: input.email } },
    create: { orgId: ctx.orgId, email: input.email, ...data },
    update: data, // re-invite: fresh token + expiry invalidates the old link
  });

  // Enqueue after the write commits, per the saas-integrations placement rule.
  await enqueue("email.org-invite", { orgId: ctx.orgId, email: input.email, token: rawToken });
}
```

Controller always responds `{ message: "Invitation sent", data: null }`,
member or not, new invite or re-invite.

Email job: add to the scaffold's `JobPayloads` AND `JOB_NAMES` in
`lib/queue.ts` (pg-boss v10 needs the name registered at startup), then handle
it in the worker per saas-integrations reference/email-jobs.md:

```ts
// lib/queue.ts additions
"email.org-invite": BaseJobPayload & {
  orgId: string;
  email: string;
  token: string; // RAW token: it exists only in the email link, never in the DB
};
```

The worker loads the org name and inviter for the template and builds the link
from typed ENV: `${ENV.FRONTEND_URL}/invitations/accept?token=${token}`.

Accept (POST /api/v1/invitations/accept, authenticated): an existing user
signs in and accepts; a new user registers first (register signs them in
immediately per reference/flows.md, the frontend carries the token through the
register redirect), then calls the same endpoint. The service binds the link
to the invited address and creates the Membership in a transaction:

```ts
export async function acceptInvitation(actorId: string, rawToken: string) {
  const tokenHash = hashToken(rawToken);

  return prisma.$transaction(async (tx) => {
    const invitation = await tx.invitation.findUnique({ where: { tokenHash } });
    const valid = invitation && !invitation.acceptedAt && invitation.expiresAt > new Date();
    if (!valid) throw new BadRequestError("Invalid or expired invitation");

    const actor = await tx.user.findUnique({ where: { id: actorId } });
    // A forwarded link must not enroll a different account.
    if (!actor || actor.email !== invitation.email) {
      throw new ForbiddenError("This invitation was issued to a different email address");
    }

    await tx.invitation.update({
      where: { id: invitation.id },
      data: { acceptedAt: new Date() }, // single-use, enforced in the same transaction
    });

    // @@unique([userId, orgId]) turns a double-accept race into a P2002,
    // which the central errorHandler maps to a 409 ConflictError.
    return tx.membership.create({
      data: { userId: actorId, orgId: invitation.orgId, role: invitation.role },
    });
  });
}
```

Controller: `{ message: "Invitation accepted", data: membership }`. Revoking a
pending invite is a hard delete of the Invitation row, org-scoped
(`DELETE /orgs/:orgId/invitations/:id`, requireMembership("ADMIN")).

## Platform-admin surface (/api/v1/admin)

PLATFORM_ADMIN routes live under `/api/v1/admin` on a SEPARATE router, never
mixed into tenant routers. They may query across orgs; that makes them the
only code allowed to omit orgId scoping, so the boundary must be loud:

```ts
// src/routes/admin/admin-routes.ts
export const adminRouter = Router();
adminRouter.use(authenticateJWT, authorize("PLATFORM_ADMIN"), platformAudit);
adminRouter.get("/orgs", asyncHandler(listAllOrgsController)); // cross-org reads live ONLY here
```

```ts
// src/middlewares/platform-audit.ts - every access is audit-logged
export function platformAudit(req: AuthenticatedRequest, _res: Response, next: NextFunction): void {
  req.log.info(
    { platformAdminId: req.user?.id, method: req.method, path: req.originalUrl, params: req.params },
    "platform admin access",
  );
  next();
}
```

Rules:
- Admin services are separate functions (e.g.
  `services/admin/org-admin-query.service.ts`) that take the platform actor
  explicitly and deliberately skip org scoping. NEVER reuse a tenant service
  by synthesizing an OrgContext the actor did not earn.
- Every access is audit-logged via the middleware above (structured, with the
  admin's id and target path). When the spec demands tamper-evident audit,
  add an AuditLog model written in the same request; the log line is the floor.
- The admin surface is for support and operations, not a super-tenant: it gets
  the same validation, pagination, and envelope rules as everything else.
