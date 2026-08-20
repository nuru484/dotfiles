# Reference: Realtime + In-App Notifications (polling, SSE, socket.io)

Read this before building a notification bell, live feed, job-status surface,
or anything "realtime". The decision ladder below exists so a build never
guesses: each tier is strictly more infrastructure than the one before it, and
you escalate ONLY when the spec demands what the cheaper tier cannot deliver.
All code follows the house conventions: layering, typed `ENV`, `CustomError`
subclasses from `#utils/errors.js`, `{ message, data }` envelope, the central
errorHandler, kebab-case filenames, `#*` subpath imports.

## Contents
- The decision ladder
- Fan-out law: the DB is the source of truth
- Notification Prisma model + API contract
- Backend layout: the notifications/ folder
- Notification services (write, mark-read, query)
- Tier 1 (DEFAULT): RTK Query polling
- Tier 2: SSE (route, registry, limiter exemption, shutdown drain)
- Tier 3: socket.io (handshake auth, origin check, scale-out)

## The decision ladder

| Tier | Use when | Mechanism |
| --- | --- | --- |
| 1. **Polling (DEFAULT)** | Notification bells, dashboards, job status; freshness of 15-30s is fine | RTK Query `pollingInterval` on the visible surface |
| 2. **SSE** | The spec DEMANDS sub-5s one-way freshness (live boards, activity feeds) | Express GET holding the response open, `text/event-stream` |
| 3. **socket.io** | The spec DEMANDS bidirectional (chat, collaborative editing, presence) | WebSocket server sharing the HTTP server |

*Why polling is the default:* it is the simplest thing that works with ALL
existing infra (auth cookie, CORS, rate limits, RTK Query cache, zero new
server surface). A 20s-stale notification bell is indistinguishable from a
live one for almost every product. Do not build tier 2 or 3 because realtime
sounds better; build it because the spec names a surface that needs it.

## Fan-out law: the DB is the source of truth

Every tier reads the same table. SSE and sockets are NUDGE channels layered on
top; they never carry state the DB does not already hold. *Why:* connections
drop, tabs close, instances restart; a missed push must cost nothing because
the next read of the table shows the truth. This also kills replay machinery:
on reconnect the client simply refetches the list (no Last-Event-ID bookkeeping).

- Domain services create Notification rows INSIDE their transactions: the
  notification commits or rolls back with the domain change that caused it.
- Publishing to open connections happens AFTER the transaction commits, the
  same placement rule as enqueue-after-commit in reference/email-jobs.md.
- Mark-read is `PATCH /api/v1/notifications/:id/read` plus a mark-all
  (`PATCH /api/v1/notifications/read-all`), owner-scoped, idempotent.

## Notification Prisma model + API contract

```prisma
model Notification {
  id        String    @id @default(cuid())
  userId    String
  user      User      @relation(fields: [userId], references: [id], onDelete: Cascade)
  orgId     String?
  type      String
  title     String
  body      String?
  href      String?
  readAt    DateTime?
  createdAt DateTime  @default(now())

  @@index([userId, readAt])
}
```

Notes:
- Notifications are user-owned: `userId` is the recipient and the ONLY scoping
  key; `orgId` is optional provenance for display and filtering. Routes stay
  under `/api/v1/notifications` (not `/orgs/:orgId/...`) because a bell spans
  orgs; ownership filtering (`userId: actor.id`) is the tenancy boundary here.
- No `deletedAt`: rows are append-only apart from `readAt` (the one mutation),
  so the soft-delete convention does not apply. If volume ever demands it,
  prune old read rows with a scheduled pg-boss job, not per-request deletes.
- `@@index([userId, readAt])` serves the two hot queries: the unread count and
  the newest-first list.

API contract (api-contracts envelopes; the unread count rides in `summary`
because `meta` is the standard pagination shape and must not fork):

```
GET   /api/v1/notifications?page=&limit=&unread=
  200 { message, data: INotification[], meta: { total, page, limit, totalPages },
        summary: { unreadCount } }
PATCH /api/v1/notifications/:id/read      200 { message, data: null }
PATCH /api/v1/notifications/read-all      200 { message, data: null }
GET   /api/v1/notifications/stream        (tier 2 only: text/event-stream)
```

The frontend mirrors `INotification` and `INotificationsResponse` in `types/`
with the same names, per api-contracts. Rows carry no hidden fields, so they
pass through without a mapper (decided once, here).

## Backend layout: the notifications/ folder

This is what the `notifications/` folder in the backend-conventions layout is
for. Files (kebab-case, role suffixes):

```
src/notifications/
  notification.service.ts        create (inside domain tx) + markRead/markAllRead
  notification-query.service.ts  list + unreadCount
  notification-validation.ts     list query schema
  notification-controllers.ts    thin controllers
  notification-routes.ts         REST routes; mounts the SSE route
  notification-sse-routes.ts     GET /stream (tier 2 only)
  sse-registry.ts                open connections, heartbeats, publish, shutdown drain
  index.ts                       barrel (backend-only convention)
```

Mounted in `src/routes/index.ts`: `router.use("/notifications", notificationRouter);`

## Notification services

```ts
// src/notifications/notification.service.ts
import type { Notification } from "@prisma/client";
import { prisma, type TransactionClient } from "#lib/prisma.js";
import { NotFoundError } from "#utils/errors.js";

export interface CreateNotificationInput {
  userId: string;
  orgId?: string;
  type: string; // "<feature>.<event>", e.g. "task.assigned"
  title: string;
  body?: string;
  href?: string; // where the client navigates on click
}

/** Called by domain services INSIDE their transaction. */
export async function createNotification(
  tx: TransactionClient,
  input: CreateNotificationInput,
): Promise<Notification> {
  return tx.notification.create({ data: input });
}

/** Idempotent: marking an already-read notification succeeds silently. */
export async function markNotificationRead(actorId: string, id: string): Promise<void> {
  const { count } = await prisma.notification.updateMany({
    where: { id, userId: actorId, readAt: null }, // owner-scoped compound where
    data: { readAt: new Date() },
  });
  if (count === 0) {
    const exists = await prisma.notification.findFirst({
      where: { id, userId: actorId },
      select: { id: true },
    });
    if (!exists) throw new NotFoundError("Notification not found"); // missing or someone else's: same 404
  }
}

export async function markAllNotificationsRead(actorId: string): Promise<void> {
  await prisma.notification.updateMany({
    where: { userId: actorId, readAt: null },
    data: { readAt: new Date() },
  });
}
```

```ts
// src/notifications/notification-query.service.ts
export async function listNotifications(actorId: string, params: ListNotificationsInput) {
  const { page, limit, skip } = parsePagination(params);
  const where = { userId: actorId, ...(params.unread ? { readAt: null } : {}) };

  const [rows, total, unreadCount] = await Promise.all([
    prisma.notification.findMany({ where, orderBy: { createdAt: "desc" }, skip, take: limit }),
    prisma.notification.count({ where }),
    prisma.notification.count({ where: { userId: actorId, readAt: null } }),
  ]);

  return { rows, meta: buildMeta(total, page, limit), summary: { unreadCount } };
}
```

The `unread` query param coerces explicitly (`z.coerce.boolean()` treats the
string "false" as true, a known Zod trap):

```ts
// src/notifications/notification-validation.ts
export const listNotificationsSchema = z.object({
  page: z.coerce.number().int().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).optional(),
  unread: z.enum(["true", "false"]).transform((v) => v === "true").optional(),
});
```

Domain-service usage, with the publish AFTER the commit (mirror of the
enqueue placement rule):

```ts
const notification = await prisma.$transaction(async (tx) => {
  const task = await assignTask(tx, ctx, input);
  return createNotification(tx, {
    userId: task.assigneeId,
    orgId: ctx.orgId,
    type: "task.assigned",
    title: `You were assigned "${task.name}"`,
    href: `/orgs/${ctx.orgId}/tasks/${task.id}`,
  });
});
publishToUser(notification.userId, "notification", notification); // no-op with zero open streams
```

## Tier 1 (DEFAULT): RTK Query polling

No new backend surface at all: the list endpoint above plus the standard
injected endpoint (frontend-conventions reference/data-layer.md). Poll the
VISIBLE surface (the bell in the header); every other consumer reads the same
cache without its own interval.

```ts
// The bell component - the query arg (undefined) MUST match the arg the
// optimistic mark-read patch targets (frontend-conventions data-layer.md).
const { data } = useGetNotificationsQuery(undefined, {
  pollingInterval: 30_000, // pick once per surface, 15-30s
  skipPollingIfUnfocused: true, // background tabs stop hitting the API
});
const unreadCount = data?.summary?.unreadCount ?? 0;
```

Mark-read is the optimistic toggle defined in frontend-conventions
`reference/data-layer.md` (updateQueryData patch, undo on error, no
invalidatesTags - the next poll reconciles). Job-status surfaces poll their
own existing endpoints the same way; do not build a push channel for a
progress bar.

## Tier 2: SSE (one-way, sub-5s)

An Express GET route holds the response open as `text/event-stream`. Auth is
the NORMAL `authenticateJWT` on the SAME httpOnly access cookie; nothing new
is minted. EventSource sends cookies automatically same-origin; the house
default is cross-origin (app on Vercel, API on Render), which needs BOTH ends
opted in:

```ts
// Frontend (client component effect; close the source in the cleanup)
const source = new EventSource(
  `${PUBLIC_ENV.SERVER_URI}/api/v1/notifications/stream`,
  { withCredentials: true }, // sends the httpOnly access cookie cross-origin
);
source.addEventListener("notification", () => {
  // The DB is the truth: nudge RTK Query to refetch instead of merging payloads by hand.
  dispatch(apiSlice.util.invalidateTags([{ type: "Notifications", id: "LIST" }]));
});
```

Server side, the existing CORS setup (security-hardening: allowlist origin
callback with `credentials: true`) already covers the preflight-less
EventSource request; no extra CORS config. The route verifies Origin itself
because `originCheck` only guards unsafe methods and this GET holds a
connection open:

```ts
// src/notifications/notification-sse-routes.ts
import { Router } from "express";
import { authenticateJWT, type AuthenticatedRequest } from "#middlewares/authenticate-jwt.js";
import { corsAllowlist } from "#middlewares/cors.js";
import { sseLimiter } from "#middlewares/rate-limit.js";
import { ForbiddenError } from "#utils/errors.js";
import { addConnection } from "#notifications/sse-registry.js";

export const notificationSseRouter = Router();

// Final path: GET /api/v1/notifications/stream
notificationSseRouter.get("/stream", sseLimiter, authenticateJWT, (req: AuthenticatedRequest, res) => {
  // originCheck covers POST/PUT/PATCH/DELETE only; a long-lived GET gets its own check.
  const origin = req.headers.origin;
  if (origin && !corsAllowlist.has(origin)) {
    throw new ForbiddenError("Origin not allowed", { layer: "SSE" });
  }

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no", // stops proxy buffering; never add compression middleware to this route
  });
  res.write("retry: 5000\n\n"); // client reconnect delay; also flushes headers

  addConnection(req.user!.id, res); // heartbeat, lifetime cap, cleanup live in the registry
});
```

Mounted from `notification-routes.ts` alongside the REST routes, so everything
lives under `/api/v1/notifications`.

The registry keys connections by the VERIFIED userId from the cookie and only
ever publishes that user's own rows:

```ts
// src/notifications/sse-registry.ts
import type { Response } from "express";

const HEARTBEAT_MS = 25_000; // under the 30-60s idle timeouts of common proxies (Render, Heroku, Cloudflare)
const MAX_LIFETIME_MS = 30 * 60 * 1000; // the access-token window: a revoked session's stream dies within it

const connections = new Map<string, Set<Response>>();

export function addConnection(userId: string, res: Response): void {
  const set = connections.get(userId) ?? new Set<Response>();
  set.add(res);
  connections.set(userId, set);

  // SSE comment frames keep the socket alive without waking the client handler.
  const heartbeat = setInterval(() => res.write(": hb\n\n"), HEARTBEAT_MS);

  // authenticateJWT ran once at connect; capping the lifetime forces a
  // reconnect, which re-runs it against the (silently refreshed) cookie.
  const lifetime = setTimeout(() => res.end(), MAX_LIFETIME_MS);

  res.on("close", () => {
    clearInterval(heartbeat);
    clearTimeout(lifetime);
    set.delete(res);
    if (set.size === 0) connections.delete(userId);
  });
}

export function publishToUser(userId: string, event: string, data: unknown): void {
  const set = connections.get(userId);
  if (!set) return;
  const frame = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
  for (const res of set) res.write(frame);
}

/** Graceful-shutdown drain: called on SIGTERM before server.close can complete. */
export function closeAllConnections(): void {
  for (const set of connections.values()) {
    for (const res of set) res.end();
  }
  connections.clear();
}
```

### Critical interaction 1: the global rate limiter

Exempt the SSE route from the global limiter's window logic. *Why:* the
window math prices request/response traffic, and EventSource auto-reconnects
forever; a user with a few tabs riding reconnects (deploys, proxy resets,
the lifetime cap) can burn the 300/15min budget, and once 429'd, EventSource
keeps retrying and never recovers. Replace the blanket with a dedicated
connection-attempt bucket so reconnect storms stay bounded
(security-hardening owns limiter mechanics; this is the one blessed exemption):

```ts
// src/middlewares/rate-limit.ts additions
const SSE_PATHS = new Set(["/api/v1/notifications/stream"]);

export const globalLimiter = rateLimit({
  // ...existing config unchanged...
  skip: (req) => SSE_PATHS.has(req.path),
});

// One connection attempt then hours of held-open response: bound the attempts.
export const sseLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 60, // reconnect attempts, not steady-state traffic
  standardHeaders: "draft-8",
  legacyHeaders: false,
  handler: rejectWith("Too many stream connections, try again later"),
});
```

### Critical interaction 2: graceful shutdown

Open SSE responses are in-flight requests that never finish, so
`server.close()` waits for them forever and every deploy rides the 10s
force-exit timer into a hard kill. Register streams with the drain (the
registry above) and end them on SIGTERM before `server.close` can complete:

```ts
// server.ts shutdown() addition, immediately before server.close(...)
closeAllConnections(); // SSE streams never finish on their own; end them so close() can
server.close(async () => {
  // ...existing boss.stop / prisma.$disconnect sequence unchanged...
});
```

Clients auto-reconnect to the new instance after the deploy; the first refetch
of the table covers anything published during the gap.

### SSE scale-out constraint

The registry is per-process. On a single instance (the Render default) that is
the whole story. With multiple instances, a publish on instance A misses
connections on instance B: bridge publishes through Postgres NOTIFY/LISTEN (no
new infra) or Redis pub/sub before scaling out, or drop back to tier 1
polling, which is multi-instance-safe by construction. Start single-instance;
record the upgrade path in PLAN.md instead of building it speculatively.

## Tier 3: socket.io (bidirectional ONLY)

Only when the spec demands two-way traffic: chat, collaborative editing,
presence. Auth happens in the handshake middleware by parsing the SAME access
cookie; the browser does NOT enforce CORS on WebSocket upgrades, so the server
must check Origin explicitly.

```ts
// src/realtime/socket-server.ts
import type { Server as HttpServer } from "node:http";
import { Server } from "socket.io";
import { parse } from "cookie";
import { verify, type JwtPayload } from "jsonwebtoken";
import type { Role } from "@prisma/client";
import ENV from "#config/env.js";
import { ACCESS_COOKIE } from "#lib/cookie-manager.js";
import { corsAllowlist } from "#middlewares/cors.js";

export function attachSocketServer(httpServer: HttpServer): Server {
  const io = new Server(httpServer, {
    // Covers socket.io's HTTP polling transport...
    cors: { origin: [...corsAllowlist], credentials: true },
    // ...and this covers the WebSocket upgrade, which browsers exempt from CORS.
    allowRequest: (req, callback) => {
      const origin = req.headers.origin;
      callback(null, !origin || corsAllowlist.has(origin)); // no Origin = non-browser client; auth still applies
    },
  });

  // Handshake auth: same cookie, same secret, same claims as authenticateJWT.
  io.use((socket, next) => {
    const cookies = parse(socket.handshake.headers.cookie ?? "");
    const token = cookies[ACCESS_COOKIE];
    if (!token) return next(new Error("Authentication required"));
    try {
      const payload = verify(token, ENV.ACCESS_TOKEN_SECRET) as JwtPayload & { role: Role };
      socket.data.user = { id: payload.sub as string, role: payload.role };
      next();
    } catch {
      next(new Error("Authentication required"));
    }
  });

  io.on("connection", (socket) => {
    socket.join(`user:${socket.data.user.id}`); // fan-out target: io.to(`user:${id}`).emit(...)
  });

  return io;
}
```

Rules:
- Server-to-client fan-out still follows the fan-out law: persist the
  Notification row in the domain transaction, emit after commit.
- Validate every client-to-server event payload with Zod before acting on it;
  a socket event is a boundary exactly like a request body.
- Shutdown: `io.close()` in the SIGTERM sequence, before `server.close`
  completes, same reasoning as the SSE drain.
- The same session-lifetime tradeoff as SSE applies: the handshake verifies
  once, so disconnect long-lived sockets periodically (or on logout events)
  if revocation must propagate faster than the access-token window.

### socket.io scale-out constraint (decided)

Start SINGLE-INSTANCE: on Render one instance serves both HTTP and sockets and
no adapter is needed. Multi-instance needs two things at once: a shared
adapter so `io.to(...)` reaches sockets on other instances
(`@socket.io/postgres-adapter` rides the existing Postgres; Redis if the
deployment already has one) and sticky sessions for the polling transport.
Document this upgrade path in PLAN.md when tier 3 ships; do not build it
before a second instance is real.
