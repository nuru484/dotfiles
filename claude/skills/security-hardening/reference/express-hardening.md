# Express Hardening Reference (full code)

Copy-ready implementations for every rule in SKILL.md, in the exact middleware
order. Stack: Express 5, TypeScript ESM. This file layers security config on
top of the project-scaffold skill's canonical infrastructure and never forks
it: typed ENV (`#config/env.js`), CustomError subclasses (`#utils/errors.js`),
central errorHandler (`#middlewares/error-handler.js`), pino logger
(`#utils/logger.js`), requestId middleware (`#middlewares/request-id.js`), and
the typed pg-boss queue (`#lib/queue.js`). All imports use the `#*` subpath
map with explicit `.js` extensions; middleware files live in `middlewares/`
(plural) with kebab-case names.

Envelope rules (api-contracts): the central errorHandler is the ONLY producer
of the error envelope `{ status: "error", message, code?, details? }`. Nothing
in this file hand-builds error JSON; every rejection throws or `next()`s a
typed error. Success responses are `{ message, data }`, never
`{ status: "success" }`.

Contents:
1. [Hardened app.ts assembly](#1-hardened-appts-assembly)
2. [Helmet config](#2-helmet-config)
3. [CORS from ENV.CORS_ACCESS](#3-cors-from-envcors_access)
4. [Rate limiters](#4-rate-limiters)
5. [originCheck CSRF middleware](#5-origincheck-csrf-middleware)
6. [Webhook raw-body route + signature verification](#6-webhook-raw-body-route)
7. [sanitize-html helper](#7-sanitize-html-helper)
8. [Upload validation (multer + file-type magic bytes)](#8-upload-validation)
9. [Logging, redaction, and request-id (scaffold modules)](#9-logging-redaction-and-request-id-scaffold-modules)

## 1. Hardened app.ts assembly

The scaffold's app.ts skeleton with the security block filled in. The numbers
match the SKILL.md order exactly.

```ts
// src/app.ts
import express from "express";
import cors from "cors";
import cookieParser from "cookie-parser";
import HTTP_STATUS_CODES from "#constants/http-status-codes.js";
import { requestId } from "#middlewares/request-id.js";
import { helmetConfig } from "#middlewares/helmet.js";
import { buildCorsOptions } from "#middlewares/cors.js";
import { globalLimiter } from "#middlewares/rate-limit.js";
import { originCheck } from "#middlewares/origin-check.js";
import { errorHandler } from "#middlewares/error-handler.js";
import { NotFoundError } from "#utils/errors.js";
import prisma from "#lib/prisma.js";
import { webhookRouter } from "#routes/webhooks/webhook-routes.js";
import v1Routes from "#routes/index.js";

const app = express();

// 1. Exactly one proxy hop on Render/Heroku. Never `true`: that trusts
//    client-supplied X-Forwarded-For and breaks rate-limit keying.
app.set("trust proxy", 1);

// 2. Request id + pino-http logger (scaffold's middlewares/request-id.ts).
//    First, so every downstream middleware, route, and the errorHandler log
//    with the correlation id. Redaction lives in #utils/logger.js.
app.use(requestId);

// 3. Security headers on every response, including errors.
app.use(helmetConfig);

// 4. CORS with credentials from the ENV allowlist. Never wildcard.
app.use(cors(buildCorsOptions()));

// 5. Rate limiting: the global blanket. The strict authLimiter attaches PER
//    CREDENTIAL ROUTE inside the auth router (see section 4), never here.
app.use(globalLimiter);

// 6. Cookie parsing before anything that authenticates.
app.use(cookieParser());

// 7. Webhook raw-body routes BEFORE express.json: signatures need the
//    untouched raw bytes. Mounted under /api/v1 like every other route, but
//    directly here (NOT via the v1 routes index) so the raw parser wins.
app.use("/api/v1/webhooks", webhookRouter);

// 8. Body cap. Raise per-route only (uploads use multer, not json()).
app.use(express.json({ limit: "100kb" }));

// 9. CSRF: verify Origin/Referer on every state-changing method.
app.use(originCheck);

// 10. Probes stay at the root, UNVERSIONED: platforms need stable paths.
app.get("/health", (_req, res) => {
  res.status(HTTP_STATUS_CODES.OK).json({ status: "ok" });
});
app.get("/ready", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.status(HTTP_STATUS_CODES.OK).json({ status: "ready" });
  } catch {
    res.status(HTTP_STATUS_CODES.SERVICE_UNAVAILABLE).json({ status: "not ready" });
  }
});

// 11. All app routes under /api/v1. The routes index mounts feature routers
//     (auth at /api/v1/auth, users, admin mounted separately from public so
//     the privilege boundary stays explicit and greppable).
app.use("/api/v1", v1Routes);

// 12. Unmatched routes become a typed 404 through the same envelope. Never
//     hand-build the JSON here.
app.use((req, _res, next) => {
  next(new NotFoundError(`Route ${req.method} ${req.originalUrl} not found`));
});

// 13. Central error handler LAST. The ONLY producer of error JSON.
app.use(errorHandler);

export default app;
```

Strict limiters attach per credential route inside the auth router, matching
auth-conventions' route paths:

```ts
// src/routes/auth/auth-routes.ts (excerpt)
import { authLimiter, passwordResetLimiter } from "#middlewares/rate-limit.js";

// Strict buckets sit on credential routes ONLY, never on the whole /auth
// mount: /auth/me and /auth/refresh-token are hit constantly by SSR and the
// silent-refresh base query, and a mount-wide bucket would throttle real
// logged-in sessions.
router.post("/register", authLimiter, registerHandlers);
router.post("/login", authLimiter, loginHandlers);
router.post("/password-reset/request", passwordResetLimiter, requestResetHandlers);
router.post("/password-reset/confirm", passwordResetLimiter, confirmResetHandlers);

// Global limiter only: high-frequency session endpoints.
router.get("/me", meHandlers);
router.post("/refresh-token", refreshHandlers);
```

## 2. Helmet config

The API returns JSON, so CSP is mostly irrelevant to it (nothing executes in a
JSON response), but a locked-down default costs nothing and hardens any stray
HTML output (errors, redirects).

```ts
// src/middlewares/helmet.ts
import helmet from "helmet";

export const helmetConfig = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'none'"],
      frameAncestors: ["'none'"],
      baseUri: ["'none'"],
      formAction: ["'none'"],
    },
  },
  crossOriginResourcePolicy: { policy: "same-site" },
  // All other helmet defaults kept: HSTS, nosniff, frameguard,
  // referrer-policy, origin-agent-cluster, etc.
});
```

## 3. CORS from ENV.CORS_ACCESS

`ENV.CORS_ACCESS` is a comma-separated origin list from the typed ENV module
(`#config/env.js`), e.g. `https://app.example.com,https://staging.example.com`.
Credentials mode plus a wildcard is both rejected by browsers and semantically
wrong: never combine them.

```ts
// src/middlewares/cors.ts
import type { CorsOptions } from "cors";
import ENV from "#config/env.js";

export const corsAllowlist: ReadonlySet<string> = new Set(
  ENV.CORS_ACCESS.split(",").map((o) => o.trim()).filter(Boolean),
);

export function buildCorsOptions(): CorsOptions {
  return {
    origin(origin, callback) {
      // No Origin header = non-browser client (curl, server-to-server,
      // health checks). CORS is a browser control, so let these through;
      // auth still applies.
      if (!origin) return callback(null, true);
      if (corsAllowlist.has(origin)) return callback(null, true);
      return callback(new Error(`Origin ${origin} not allowed by CORS`));
    },
    credentials: true, // cookies cross-origin; requires exact origin echo
    methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
    maxAge: 86_400, // cache preflights for a day
  };
}
```

## 4. Rate limiters

express-rate-limit v7+: `limit` (not `max`), standard RateLimit headers.
Keyed by `req.ip`, which is correct because of `trust proxy = 1`. No
hand-built JSON: the `handler` option forwards a typed
`TooManyRequestsError` (429, code `RATE_LIMITED`) so the central errorHandler
produces the envelope.

```ts
// src/middlewares/rate-limit.ts
import rateLimit, { type Options } from "express-rate-limit";
import { TooManyRequestsError } from "#utils/errors.js";

const rejectWith =
  (message: string): Options["handler"] =>
  (_req, _res, next) =>
    next(new TooManyRequestsError(message, { layer: "RateLimit" }));

// Blanket protection: generous enough for real users, hostile to scrapers.
export const globalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300, // 300 requests / 15 min per IP
  standardHeaders: "draft-8",
  legacyHeaders: false,
  handler: rejectWith("Too many requests, try again later"),
});

// Credential endpoints are brute-force targets: keep this tight. Attached
// per route inside the auth router (section 1), NOT on the /auth mount.
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10, // 10 attempts / 15 min per IP
  standardHeaders: "draft-8",
  legacyHeaders: false,
  skipSuccessfulRequests: false, // count successes too: stops slow spraying
  handler: rejectWith("Too many attempts, try again in 15 minutes"),
});

// Password reset triggers email: throttle hard to stop mail-bombing. Applied
// to POST /auth/password-reset/request and /confirm (auth-conventions paths).
export const passwordResetLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: "draft-8",
  legacyHeaders: false,
  handler: rejectWith("Too many reset requests, try again in 15 minutes"),
});
```

Multi-dyno note: the default memory store is per-process. When running more
than one instance, back these with a shared store (e.g. `rate-limit-postgresql`
or a Redis store) so limits hold across dynos.

## 5. originCheck CSRF middleware

Cookie auth cross-origin means CSRF is in scope. `sameSite: "lax"` on the
access cookie plus this check covers it: browsers always attach `Origin` to
cross-origin unsafe requests and attackers cannot forge it. Fail closed when
both headers are missing. If a route must serve non-browser clients with
cookie-less bearer auth, exempt it explicitly, never globally. Rejection goes
through a typed `ForbiddenError`; the errorHandler renders the envelope.

```ts
// src/middlewares/origin-check.ts
import type { Request, Response, NextFunction } from "express";
import { ForbiddenError } from "#utils/errors.js";
import { corsAllowlist } from "#middlewares/cors.js";

const UNSAFE_METHODS = new Set(["POST", "PUT", "PATCH", "DELETE"]);

export function originCheck(req: Request, _res: Response, next: NextFunction): void {
  if (!UNSAFE_METHODS.has(req.method)) return next();

  const origin =
    req.headers.origin ?? originOf(req.headers.referer);

  if (!origin || !corsAllowlist.has(origin)) {
    return next(
      new ForbiddenError("Cross-origin request rejected", {
        layer: "CSRF",
        code: "CSRF_ORIGIN_MISMATCH",
      }),
    );
  }
  return next();
}

function originOf(referer: string | undefined): string | undefined {
  if (!referer) return undefined;
  try {
    return new URL(referer).origin;
  } catch {
    return undefined; // malformed Referer fails closed
  }
}
```

Cookies that pair with it are OWNED by the auth-conventions skill's
CookieManager (`#lib/cookie-manager.js`), the single place auth cookies are
set. It sets a dual cookie: the access cookie is `httpOnly`, `secure` in
production, `sameSite: "lax"`, `path: "/"`; the refresh cookie is
`sameSite: "strict"` and path-scoped to the refresh endpoint under
`/api/v1/auth` so the long-lived token only ever travels on refresh calls.
This skill only VERIFIES those flags in review. Never set auth cookies with a
raw `res.cookie` call; route everything through CookieManager.

If `sameSite: "none"` ever becomes required (iframe embedding), add a
double-submit token: random value set in a non-httpOnly cookie at login, sent
back by the frontend in an `X-CSRF-Token` header, compared with
`crypto.timingSafeEqual` server-side on every unsafe request.

## 6. Webhook raw-body route

Mounted in app.ts at `/api/v1/webhooks` BEFORE `express.json()` (order item
7). `express.raw` keeps `req.body` as a Buffer, which the signature is
computed over. Verify first, then Zod-parse, then queue and answer fast:
providers time out slow handlers and redeliver. `PAYMENT_WEBHOOK_SECRET` is
added to `config/env.ts` via `envRequired`, like every new variable.

```ts
// src/routes/webhooks/webhook-routes.ts
import { Router, raw } from "express";
import { createHmac, timingSafeEqual } from "node:crypto";
import ENV from "#config/env.js";
import { UnauthorizedError } from "#utils/errors.js";
import { asyncHandler } from "#utils/async-handler.js";
import { enqueue } from "#lib/queue.js";
import { paymentEventSchema } from "#validations/webhooks/payment-event-validation.js";

export const webhookRouter = Router();

function verifySignature(rawBody: Buffer, signatureHeader: string | undefined): boolean {
  if (!signatureHeader) return false;
  const expected = createHmac("sha256", ENV.PAYMENT_WEBHOOK_SECRET)
    .update(rawBody)
    .digest();
  let received: Buffer;
  try {
    received = Buffer.from(signatureHeader, "hex");
  } catch {
    return false;
  }
  // timingSafeEqual throws on length mismatch: check first.
  return received.length === expected.length && timingSafeEqual(received, expected);
}

// Final path: POST /api/v1/webhooks/payments
webhookRouter.post(
  "/payments",
  raw({ type: "application/json", limit: "1mb" }),
  asyncHandler(async (req, res) => {
    const signature = req.headers["x-webhook-signature"];
    if (!verifySignature(req.body, typeof signature === "string" ? signature : undefined)) {
      // Typed error: the central errorHandler renders the envelope.
      throw new UnauthorizedError("Invalid webhook signature", {
        layer: "Webhook",
        code: "WEBHOOK_SIGNATURE_INVALID",
      });
    }

    // Only Zod-parse AFTER the signature proves provenance.
    const event = paymentEventSchema.parse(JSON.parse(req.body.toString("utf8")));

    // Typed queue helper from the scaffold, "<feature>.<action>" job name.
    // singletonKey makes redeliveries no-ops, and the worker also upserts by
    // event.id as the second line of defense. req.id rides along so the job
    // stays correlated with this request.
    await enqueue(
      "payments.event-received",
      { event, requestId: String(req.id) },
      { singletonKey: event.id },
    );

    // 2xx fast: real work happens in the pg-boss worker.
    res.status(200).json({ message: "Webhook received", data: null });
  }),
);
```

Register the job in the scaffold's typed job map so the enqueue call and the
worker handler type-check against each other:

```ts
// src/lib/queue.ts (additions to the scaffold's JobPayloads + JOB_NAMES)
import type { PaymentEvent } from "#types/webhooks/payment-event.types.js";

export interface JobPayloads {
  // ...existing jobs...
  "payments.event-received": BaseJobPayload & { event: PaymentEvent };
}
// and add "payments.event-received" to JOB_NAMES.
```

For providers with SDKs (e.g. Stripe), use their verifier instead of hand-rolled
HMAC: `stripe.webhooks.constructEvent(req.body, sigHeader, ENV.STRIPE_WEBHOOK_SECRET)`.
The raw-body mounting requirement is identical.

## 7. sanitize-html helper

One shared policy, used before storing AND as belt-and-braces before rendering.
Allowlist, never blocklist: unknown tags are dropped.

```ts
// src/lib/sanitize.ts
import sanitizeHtml from "sanitize-html";

const RICH_TEXT_POLICY: sanitizeHtml.IOptions = {
  allowedTags: [
    "p", "br", "strong", "em", "u", "s",
    "ol", "ul", "li", "blockquote",
    "h2", "h3", "code", "pre", "a",
  ],
  allowedAttributes: { a: ["href", "rel", "target"] },
  allowedSchemes: ["https", "http", "mailto"], // blocks javascript: and data:
  disallowedTagsMode: "discard",
  transformTags: {
    a: sanitizeHtml.simpleTransform("a", {
      rel: "noopener noreferrer nofollow", // no tab-nabbing, no SEO abuse
      target: "_blank",
    }),
  },
};

export function sanitizeRichText(dirty: string): string {
  return sanitizeHtml(dirty, RICH_TEXT_POLICY);
}

// For user content interpolated into plain contexts (emails, alt text):
// strip ALL tags and encode entities instead of allowing any HTML.
export function escapeUserText(dirty: string): string {
  return sanitizeHtml(dirty, { allowedTags: [], allowedAttributes: {} });
}
```

## 8. Upload validation

Extension and client `Content-Type` are attacker-controlled: detect the real
type from magic bytes with `file-type`, cap size in multer, randomize the
stored name, and re-encode through sharp so the processing pipeline is the
trust boundary (embedded payloads do not survive re-encoding). Never serve
files back from the raw upload path.

```ts
// src/middlewares/upload.ts
import multer from "multer";
import { fileTypeFromBuffer } from "file-type";
import sharp from "sharp";
import { randomUUID } from "node:crypto";
import { BadRequestError } from "#utils/errors.js";

const ALLOWED_MIME = new Set(["image/jpeg", "image/png", "image/webp"]);

// memoryStorage: the buffer is validated and re-encoded before anything
// touches disk or object storage, and limits cap memory use.
export const imageUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1 }, // 5 MB, one file
});

export interface CleanImage {
  storedName: string; // random name: user filenames enable traversal/overwrite
  buffer: Buffer;
  contentType: "image/webp";
}

export async function validateAndProcessImage(input: Buffer): Promise<CleanImage> {
  const detected = await fileTypeFromBuffer(input);
  if (!detected || !ALLOWED_MIME.has(detected.mime)) {
    // The house catalog has no 415 constant: 400 with a stable code is fine.
    throw new BadRequestError("Unsupported file type", {
      layer: "Upload",
      code: "UNSUPPORTED_MEDIA_TYPE",
    });
  }

  // Re-encode: the trust boundary. Strips metadata, polyglots, embedded JS.
  const buffer = await sharp(input, { limitInputPixels: 25_000_000 })
    .rotate() // honor EXIF orientation, then discard EXIF
    .webp({ quality: 82 })
    .toBuffer();

  return { storedName: `${randomUUID()}.webp`, buffer, contentType: "image/webp" };
}
```

Route usage (per-route only; the global JSON limit stays 100kb). Success uses
the `{ message, data }` envelope; failures throw typed errors:

```ts
router.post(
  "/me/avatar",
  imageUpload.single("avatar"),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new BadRequestError("No file provided", {
        layer: "Upload",
        code: "FILE_REQUIRED",
      });
    }
    const clean = await validateAndProcessImage(req.file.buffer);
    const url = await storage.put(clean); // object storage, NOT app filesystem
    res.status(200).json({ message: "Avatar uploaded", data: { url } });
  }),
);
```

## 9. Logging, redaction, and request-id (scaffold modules)

Do NOT create a second logger or request-id middleware here: the scaffold owns
both. `#utils/logger.js` is the single pino instance (redaction at the
transport level, pretty in dev, JSON in prod), and
`#middlewares/request-id.js` is the pino-http middleware that honors an
inbound `x-request-id`, otherwise mints a UUID, sets the response header,
attaches a child logger as `req.log`, and skips `/health` and `/ready`
autologging. app.ts mounts it first (order item 2), so `req.id` and `req.log`
are available to every downstream handler, service log line, and the central
errorHandler for correlation.

This skill's contribution is the redact list. The scaffold logger ships with
the credential basics (`*.password`, `*.token`, `*.secret`, `*.key`,
`*.authorization`, auth/cookie headers). Extend `redact.paths` in
`#utils/logger.js` with the credential and PII fields the domain adds:

```ts
// src/utils/logger.ts (additions to the scaffold's redact.paths)
"*.currentPassword",
"*.newPassword",
"*.passwordConfirm",
"*.accessToken",
"*.refreshToken",
"*.apiKey",
"*.otp",
// Common PII fields at any depth
"*.email",
"*.phone",
"*.address",
"*.dateOfBirth",
"*.cardNumber",
"*.ssn",
```

Never log request bodies or full query strings by default: that is where PII
lives. Prefer `req.log` over the bare logger inside request handling, and pass
`req.id` into every job payload enqueued during a request (see section 6) so
async work stays traceable.
