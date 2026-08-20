# Reference: Backend Infrastructure (canonical code)

Copy these modules into new repos as-is, then extend for the domain. Keep the
exported names and contracts: every other skill (`backend-conventions`,
`api-contracts`, `observability`) refers to them by these names. Imports use
the `#*` -> `./src/*` subpath map with explicit `.js` extensions (ESM).

## Contents

1. [config/env.ts](#1-configenvts)
2. [constants/http-status-codes.ts](#2-constantshttp-status-codests)
3. [utils/errors.ts](#3-utilserrorsts)
4. [middlewares/error-handler.ts](#4-middlewareserror-handlerts)
5. [utils/async-handler.ts](#5-utilsasync-handlerts)
6. [middlewares/validate-request.ts + validation-middleware.ts](#6-middlewaresvalidate-requestts--validation-middlewarets)
7. [utils/paginate.ts](#7-utilspaginatets)
8. [utils/logger.ts](#8-utilsloggerts)
9. [middlewares/request-id.ts](#9-middlewaresrequest-idts)
10. [lib/prisma.ts + lib/soft-delete-extension.ts](#10-libprismats--libsoft-delete-extensionts)
11. [lib/queue.ts + the jobs pattern](#11-libqueuets--the-jobs-pattern)
12. [app.ts skeleton](#12-appts-skeleton)
13. [server.ts + worker.ts (graceful shutdown)](#13-serverts--workerts-graceful-shutdown)

---

## 1. config/env.ts

The only file that reads `process.env`. Everything else imports `ENV`, so a
misconfigured deploy fails at startup with a named variable, not mid-request.

```ts
import "dotenv/config"; // load .env before anything reads process.env

export function envRequired(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env variable: ${name}`);
  return value;
}

export function envOptional(name: string): string | undefined {
  const value = process.env[name];
  return value?.length ? value : undefined;
}

export function envNumber(name: string, defaultValue?: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") {
    if (defaultValue === undefined) {
      throw new Error(`Missing required numeric env variable: ${name}`);
    }
    return defaultValue;
  }
  const parsed = Number(raw);
  if (Number.isNaN(parsed)) {
    throw new Error(`Env variable ${name} must be a number, got "${raw}"`);
  }
  return parsed;
}

export function envBool(name: string, defaultValue = false): boolean {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return defaultValue;
  return ["1", "true", "yes", "on"].includes(raw.toLowerCase());
}

export const ENV = {
  PORT: envNumber("PORT", 4000), // frontend dev server owns 3000 (see local-dev.md)
  NODE_ENV: process.env.NODE_ENV ?? "development",
  DATABASE_URL: envRequired("DATABASE_URL"),
  ACCESS_TOKEN_SECRET: envRequired("ACCESS_TOKEN_SECRET"),
  REFRESH_TOKEN_SECRET: envRequired("REFRESH_TOKEN_SECRET"),
  ACCESS_TOKEN_EXPIRY: envOptional("ACCESS_TOKEN_EXPIRY") ?? "30m",
  REFRESH_TOKEN_EXPIRY: envOptional("REFRESH_TOKEN_EXPIRY") ?? "7d",
  CORS_ACCESS: envRequired("CORS_ACCESS"), // consumed by the security-hardening skill's cors setup
  COOKIE_DOMAIN: envOptional("COOKIE_DOMAIN"), // unset in dev: host-only cookies on localhost
  FRONTEND_URL: envRequired("FRONTEND_URL"),
  LOG_LEVEL: envOptional("LOG_LEVEL"), // logger falls back by NODE_ENV when unset
} as const;

export default ENV;
```

Rules: add every new variable here via the four helpers; never hardcode a
value `ENV` already defines (sign tokens with `ENV.ACCESS_TOKEN_EXPIRY`, not a
literal `"30m"`).

## 2. constants/http-status-codes.ts

Named constants instead of magic numbers, so intent is greppable.

```ts
export const HTTP_STATUS_CODES = {
  OK: 200,
  CREATED: 201,
  ACCEPTED: 202,
  NO_CONTENT: 204,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  CONFLICT: 409,
  UNPROCESSABLE_ENTITY: 422,
  TOO_MANY_REQUESTS: 429,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
} as const;

export type HttpStatusCode =
  (typeof HTTP_STATUS_CODES)[keyof typeof HTTP_STATUS_CODES];

export default HTTP_STATUS_CODES;
```

## 3. utils/errors.ts

One error model. Services throw these; the central errorHandler formats them.
The `code` values come from the shared catalog in `api-contracts` (extend the
catalog there when adding one). Severity defaults are chosen so expected 4xx
errors log at `warn` and 5xx at `error`/`fatal` (see the observability skill).

```ts
import HTTP_STATUS_CODES from "#constants/http-status-codes.js";

export enum ErrorSeverity {
  LOW = "LOW",
  MEDIUM = "MEDIUM",
  HIGH = "HIGH",
  CRITICAL = "CRITICAL",
}

export interface CustomErrorOptions {
  layer?: string;
  severity?: ErrorSeverity;
  code?: string;
  context?: Record<string, unknown>;
}

export class CustomError extends Error {
  readonly status: number;
  readonly layer: string;
  readonly severity: ErrorSeverity;
  readonly timestamp: Date;
  readonly code?: string;
  readonly context?: Record<string, unknown>;

  constructor(status: number, message: string, options: CustomErrorOptions = {}) {
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

export class NotFoundError extends CustomError {
  constructor(message = "Resource not found", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.NOT_FOUND, message, {
      severity: ErrorSeverity.LOW,
      code: "NOT_FOUND",
      ...options,
    });
  }
}

export class BadRequestError extends CustomError {
  constructor(message = "Bad request", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.BAD_REQUEST, message, {
      severity: ErrorSeverity.LOW,
      code: "BAD_REQUEST",
      ...options,
    });
  }
}

export class ValidationError extends CustomError {
  constructor(message = "Validation Error", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.BAD_REQUEST, message, {
      severity: ErrorSeverity.LOW,
      code: "VALIDATION_ERROR",
      ...options,
    });
  }
}

export class UnauthorizedError extends CustomError {
  constructor(message = "Authentication required", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.UNAUTHORIZED, message, {
      severity: ErrorSeverity.MEDIUM,
      code: "UNAUTHORIZED",
      ...options,
    });
  }
}

export class ForbiddenError extends CustomError {
  constructor(
    message = "You do not have permission to perform this action",
    options: CustomErrorOptions = {},
  ) {
    super(HTTP_STATUS_CODES.FORBIDDEN, message, {
      severity: ErrorSeverity.MEDIUM,
      code: "FORBIDDEN",
      ...options,
    });
  }
}

export class ConflictError extends CustomError {
  constructor(message = "Resource already exists", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.CONFLICT, message, {
      severity: ErrorSeverity.MEDIUM,
      code: "CONFLICT",
      ...options,
    });
  }
}

export class TooManyRequestsError extends CustomError {
  constructor(
    message = "Too many requests, try again later",
    options: CustomErrorOptions = {},
  ) {
    super(HTTP_STATUS_CODES.TOO_MANY_REQUESTS, message, {
      severity: ErrorSeverity.MEDIUM,
      code: "RATE_LIMITED",
      ...options,
    });
  }
}

export class MethodNotAllowedError extends CustomError {
  constructor(message = "Method not allowed", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.METHOD_NOT_ALLOWED, message, {
      severity: ErrorSeverity.LOW,
      code: "METHOD_NOT_ALLOWED",
      ...options,
    });
  }
}

export class InternalServerError extends CustomError {
  constructor(message = "Internal server error", options: CustomErrorOptions = {}) {
    super(HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR, message, {
      severity: ErrorSeverity.HIGH,
      code: "INTERNAL_SERVER_ERROR",
      ...options,
    });
  }
}
```

## 4. middlewares/error-handler.ts

The ONLY producer of the error envelope
`{ status: "error", message, code?, details? }`. Registered last in `app.ts`.
It converts Prisma errors to typed errors, redacts secrets before logging,
mints an `errorId` the client can quote back, picks the log level from
severity, masks 500 messages in production, and exposes `details` only for
`VALIDATION_ERROR` (internals of other errors stay internal).

```ts
import { randomUUID } from "node:crypto";
import type { ErrorRequestHandler, Request } from "express";
import { Prisma } from "@prisma/client";
import ENV from "#config/env.js";
import logger from "#utils/logger.js";
import HTTP_STATUS_CODES from "#constants/http-status-codes.js";
import {
  BadRequestError,
  ConflictError,
  CustomError,
  ErrorSeverity,
  InternalServerError,
  NotFoundError,
} from "#utils/errors.js";

const SENSITIVE_KEYS = ["password", "token", "secret", "key", "authorization"];

/** Deep-copies context, replacing any key that smells like a secret. */
const redact = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>).map(([key, nested]) =>
        SENSITIVE_KEYS.some((s) => key.toLowerCase().includes(s))
          ? [key, "[REDACTED]"]
          : [key, redact(nested)],
      ),
    );
  }
  return value;
};

/** Maps known Prisma error codes onto the typed error model. */
const handlePrismaError = (
  error: Prisma.PrismaClientKnownRequestError,
): CustomError => {
  switch (error.code) {
    case "P2002": {
      const target = Array.isArray(error.meta?.target)
        ? (error.meta.target as string[]).join(", ")
        : "value";
      return new ConflictError(`A record with this ${target} already exists`, {
        layer: "Database",
        context: { prismaCode: error.code },
      });
    }
    case "P2025":
      return new NotFoundError("Record not found", {
        layer: "Database",
        context: { prismaCode: error.code },
      });
    case "P2003":
      return new BadRequestError("Related record does not exist", {
        layer: "Database",
        context: { prismaCode: error.code },
      });
    default:
      return new InternalServerError("Database error", {
        layer: "Database",
        severity: ErrorSeverity.HIGH,
        context: { prismaCode: error.code },
      });
  }
};

/** Severity decides the level: expected 4xx warn, unexpected error/fatal. */
const logLevelFor = (severity: ErrorSeverity): "warn" | "error" | "fatal" => {
  switch (severity) {
    case ErrorSeverity.LOW:
    case ErrorSeverity.MEDIUM:
      return "warn";
    case ErrorSeverity.HIGH:
      return "error";
    case ErrorSeverity.CRITICAL:
      return "fatal";
  }
};

export const errorHandler: ErrorRequestHandler = (err: unknown, req, res, _next) => {
  let error: CustomError;
  if (err instanceof CustomError) error = err;
  else if (err instanceof Prisma.PrismaClientKnownRequestError) {
    error = handlePrismaError(err);
  } else {
    error = new InternalServerError(
      err instanceof Error ? err.message : "Unexpected error",
      { context: { originalName: err instanceof Error ? err.name : typeof err } },
    );
  }

  const errorId = randomUUID();
  // pino-http (request-id.ts) attaches req.id and a child logger; fall back
  // to the base logger so the handler also works in tests without it.
  const requestId = (req as Request & { id?: string | number }).id;
  const log = (req as Request & { log?: typeof logger }).log ?? logger;

  log[logLevelFor(error.severity)](
    {
      errorId,
      requestId,
      status: error.status,
      code: error.code,
      layer: error.layer,
      severity: error.severity,
      method: req.method,
      path: req.originalUrl,
      context: redact(error.context ?? {}),
      stack: error.stack,
    },
    error.message,
  );

  // Never leak internals from a 500 in production; the errorId links the
  // client's report to the full log line.
  const isServerError = error.status >= HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR;
  const message =
    isServerError && ENV.NODE_ENV === "production"
      ? `Something went wrong. Reference: ${errorId}`
      : error.message;

  const validationDetails =
    error.code === "VALIDATION_ERROR" ? error.context?.errors : undefined;

  res.status(error.status).json({
    status: "error",
    message,
    ...(error.code ? { code: error.code } : {}),
    ...(validationDetails ? { details: validationDetails } : {}),
  });
};

export default errorHandler;
```

## 5. utils/async-handler.ts

```ts
import type { NextFunction, Request, Response } from "express";

/**
 * Express 5 forwards rejected promises from async handlers to the error
 * middleware natively, so new Express 5 code may omit this wrapper. Keep it
 * for explicitness and for older Express 4 repos, where a rejected promise
 * would otherwise hang the request. Wrapping in Express 5 is harmless.
 */
export const asyncHandler =
  <T extends Request = Request>(
    fn: (req: T, res: Response, next: NextFunction) => Promise<void>,
  ) =>
  (req: T, res: Response, next: NextFunction): Promise<void> =>
    Promise.resolve(fn(req, res, next)).catch(next);

export default asyncHandler;
```

## 6. middlewares/validate-request.ts + validation-middleware.ts

Zod at the boundary. The parsed (coerced) result is written back to `req`, so
handlers read typed values and the schema's inferred type doubles as the
service input type.

```ts
// middlewares/validate-request.ts
import type { NextFunction, Request, Response } from "express";
import { ZodError, type ZodType } from "zod";
import { ValidationError } from "#utils/errors.js";

export type ValidationTarget = "body" | "query" | "params";

export const validateRequest =
  <T extends ZodType>(schema: T, target: ValidationTarget = "body") =>
  (req: Request, _res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[target]);
      // Express 5: req.query is a getter, so plain assignment throws.
      // Redefine the property instead; body and params are writable.
      if (target === "query") {
        Object.defineProperty(req, "query", {
          value: parsed,
          writable: true,
          configurable: true,
          enumerable: true,
        });
      } else {
        (req as unknown as Record<string, unknown>)[target] = parsed;
      }
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        return next(
          new ValidationError("Validation Error", {
            layer: "Request Validation",
            code: "VALIDATION_ERROR",
            context: {
              errors: err.issues.map((issue) => ({
                field: issue.path.join("."),
                message: issue.message,
              })),
            },
          }),
        );
      }
      next(err);
    }
  };

export default validateRequest;
```

```ts
// middlewares/validation-middleware.ts
import type { RequestHandler } from "express";
import type { ZodType } from "zod";
import { validateRequest, type ValidationTarget } from "#middlewares/validate-request.js";

/**
 * Named entry points controllers spread into their RequestHandler arrays:
 *   [...validationMiddleware.create(schema), handler]
 * Each returns an array so extra per-feature middleware can be prepended
 * later without changing every call site.
 */
export const validationMiddleware = {
  create: (schema: ZodType): RequestHandler[] => [validateRequest(schema, "body")],
  update: (schema: ZodType): RequestHandler[] => [validateRequest(schema, "body")],
  query: (schema: ZodType): RequestHandler[] => [validateRequest(schema, "query")],
  params: (schema: ZodType): RequestHandler[] => [validateRequest(schema, "params")],
  custom: (schema: ZodType, target: ValidationTarget): RequestHandler[] => [
    validateRequest(schema, target),
  ],
};

export default validationMiddleware;
```

## 7. utils/paginate.ts

THE pagination defaults for every list endpoint: page 1, limit 10, capped at
100. Do not invent per-feature defaults; clients and the api-contracts skill
rely on these. The cap exists so no request can dump a whole table.

```ts
export const PAGINATION_DEFAULTS = { page: 1, limit: 10, maxLimit: 100 } as const;

export interface IPaginationParams {
  page?: number;
  limit?: number;
}

export interface IPagination {
  page: number;
  limit: number;
  skip: number;
}

export interface IPaginationMeta {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

/** Normalizes already-validated query params into page/limit/skip. */
export const parsePagination = (params: IPaginationParams = {}): IPagination => {
  const page = Math.max(
    PAGINATION_DEFAULTS.page,
    Math.trunc(params.page ?? PAGINATION_DEFAULTS.page),
  );
  const limit = Math.min(
    PAGINATION_DEFAULTS.maxLimit,
    Math.max(1, Math.trunc(params.limit ?? PAGINATION_DEFAULTS.limit)),
  );
  return { page, limit, skip: (page - 1) * limit };
};

/** Builds the meta object every list response carries. */
export const buildMeta = (
  total: number,
  page: number,
  limit: number,
): IPaginationMeta => ({
  total,
  page,
  limit,
  totalPages: Math.ceil(total / limit),
});
```

Usage: the query service calls `parsePagination` on its filter input, runs
`findMany({ skip, take: limit })` and `count` with the same `where` (in
`Promise.all`), and the controller responds with
`{ message, data, meta: buildMeta(total, page, limit), summary? }`.

## 8. utils/logger.ts

One logger for the whole process: pretty in dev, JSON in prod, secrets
redacted at the transport level so a careless log call cannot leak them.

```ts
import { pino } from "pino";
import ENV from "#config/env.js";

const level = ENV.LOG_LEVEL ?? (ENV.NODE_ENV === "production" ? "info" : "debug");

export const logger = pino({
  level,
  redact: {
    paths: [
      "*.password",
      "*.token",
      "*.secret",
      "*.key",
      "*.authorization",
      "req.headers.authorization",
      "req.headers.cookie",
      'res.headers["set-cookie"]',
    ],
    censor: "[REDACTED]",
  },
  transport:
    ENV.NODE_ENV === "development"
      ? {
          target: "pino-pretty",
          options: { colorize: true, translateTime: "HH:MM:ss" },
        }
      : undefined,
});

export default logger;
```

Log objects, not interpolated strings:
`logger.info({ requestId, donationId }, "donation created")`.

## 9. middlewares/request-id.ts

Per-request correlation via pino-http: honor an inbound `x-request-id` (so
ids survive proxies and service hops), otherwise mint one with
`crypto.randomUUID`, return it in the response header, and attach a child
logger as `req.log` whose every line carries `requestId`. Prefer `req.log`
over the bare logger inside request handling.

```ts
import { randomUUID } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { pinoHttp } from "pino-http";
import logger from "#utils/logger.js";

export const requestId = pinoHttp({
  logger,
  genReqId: (req: IncomingMessage, res: ServerResponse): string => {
    const inbound = req.headers["x-request-id"];
    const id =
      typeof inbound === "string" && inbound.length > 0 ? inbound : randomUUID();
    res.setHeader("x-request-id", id);
    return id;
  },
  // Bind only { requestId } to req.log instead of the whole request object,
  // and name the field requestId to match the observability conventions.
  quietReqLogger: true,
  customAttributeKeys: { reqId: "requestId" },
  autoLogging: {
    ignore: (req) => req.url === "/health" || req.url === "/ready",
  },
});

export default requestId;
```

pino-http ships type augmentations, so `req.id` and `req.log` are typed once
it is installed. Pass `req.id` into any job enqueued during the request (see
section 11) so async work stays traceable.

## 10. lib/prisma.ts + lib/soft-delete-extension.ts

Soft deletes: mutable models carry `deletedAt DateTime?`; "delete" means
setting it (services do `update({ data: { deletedAt: new Date() } })`). The
extension auto-scopes predicate reads to non-deleted rows. `findUnique` is
DELIBERATELY unscoped: it is the seam for finding a deleted row on purpose
(reactivation, payment settlement, idempotent webhooks). Mentioning
`deletedAt` anywhere in a `where` opts that query out of auto-scoping.

```ts
// lib/soft-delete-extension.ts
import { Prisma } from "@prisma/client";

/** Operations that take a where filter and must not see soft-deleted rows. */
const SCOPED_OPERATIONS = new Set([
  "findMany",
  "findFirst",
  "findFirstOrThrow",
  "count",
  "aggregate",
  "groupBy",
]);

/**
 * Models WITHOUT a deletedAt column (pure join / append-only tables). List
 * them here so the extension skips them instead of emitting an invalid filter.
 */
const UNSCOPED_MODELS = new Set<string>([]);

/**
 * True when the caller already filters on deletedAt anywhere in the where
 * tree (including AND/OR/NOT). An explicit predicate is the opt-in for
 * reading deleted rows, so the extension must respect it.
 */
const mentionsDeletedAt = (where: unknown): boolean => {
  if (!where || typeof where !== "object") return false;
  const clause = where as Record<string, unknown>;
  if ("deletedAt" in clause) return true;
  return ["AND", "OR", "NOT"].some((key) => {
    const nested = clause[key];
    if (Array.isArray(nested)) return nested.some(mentionsDeletedAt);
    return mentionsDeletedAt(nested);
  });
};

export const softDeleteExtension = Prisma.defineExtension({
  name: "soft-delete",
  query: {
    $allModels: {
      async $allOperations({ model, operation, args, query }) {
        if (!SCOPED_OPERATIONS.has(operation) || UNSCOPED_MODELS.has(model)) {
          return query(args);
        }
        const current = (args ?? {}) as { where?: Record<string, unknown> };
        if (mentionsDeletedAt(current.where)) return query(args);
        return query({
          ...current,
          where: { ...current.where, deletedAt: null },
        } as typeof args);
      },
    },
  },
});
```

```ts
// lib/prisma.ts
import { PrismaClient } from "@prisma/client";
import ENV from "#config/env.js";
import { softDeleteExtension } from "#lib/soft-delete-extension.js";

/** The single extended client every module imports. Never new up another. */
export const prisma = new PrismaClient({
  datasourceUrl: ENV.DATABASE_URL,
  log: ENV.NODE_ENV === "development" ? ["warn", "error"] : ["error"],
}).$extends(softDeleteExtension);

/**
 * The client type inside prisma.$transaction callbacks. Helpers that run in a
 * transaction take this as a parameter (never import the singleton), which
 * keeps them composable and preserves the soft-delete scoping in the types.
 */
export type TransactionClient = Omit<
  typeof prisma,
  "$connect" | "$disconnect" | "$on" | "$transaction" | "$use" | "$extends"
>;

export default prisma;
```

## 11. lib/queue.ts + the jobs pattern

pg-boss rides on the same Postgres instance: no extra broker, transactional
enqueue is possible, retries are durable. Job names are `"<feature>.<action>"`.
Default retry policy: 3 attempts with exponential backoff. Every payload
carries the originating `requestId` when enqueued from a request (see the
observability skill). API changed across pg-boss majors; this targets v10
(`work` delivers job batches), so verify the installed major per the version
rule.

```ts
// lib/queue.ts
import PgBoss from "pg-boss";
import ENV from "#config/env.js";
import logger from "#utils/logger.js";

interface BaseJobPayload {
  /** The requestId of the request that enqueued the job, for correlation. */
  requestId?: string;
}

/**
 * The typed job map: key = queue name ("<feature>.<action>"),
 * value = payload type. Add every new job here; enqueue and registerWorker
 * derive their types from it, so a payload mismatch fails at compile time.
 */
export interface JobPayloads {
  "email.send-welcome": BaseJobPayload & { userId: string };
  "email.send-receipt": BaseJobPayload & { donationId: string };
}

export type JobName = keyof JobPayloads;

/** Keep in sync with JobPayloads; `satisfies` rejects unknown names. */
export const JOB_NAMES = [
  "email.send-welcome",
  "email.send-receipt",
] as const satisfies readonly JobName[];

export const boss = new PgBoss({ connectionString: ENV.DATABASE_URL });

boss.on("error", (error) => logger.error({ err: error }, "pg-boss error"));

let started = false;

/** Start pg-boss once per process; v10 requires queues to exist before send. */
export const startQueue = async (): Promise<void> => {
  if (started) return;
  await boss.start();
  await Promise.all(JOB_NAMES.map((name) => boss.createQueue(name)));
  started = true;
};

/** House retry policy; override per job via options when a job needs more. */
const DEFAULT_SEND_OPTIONS: PgBoss.SendOptions = {
  retryLimit: 3,
  retryDelay: 30, // seconds before the first retry
  retryBackoff: true, // exponential: 30s, 60s, 120s
};

export const enqueue = async <N extends JobName>(
  name: N,
  payload: JobPayloads[N],
  options: PgBoss.SendOptions = {},
): Promise<string | null> =>
  boss.send(name, payload, { ...DEFAULT_SEND_OPTIONS, ...options });

/** Registers a typed handler. pg-boss v10 delivers batches, so iterate. */
export const registerWorker = async <N extends JobName>(
  name: N,
  handler: (payload: JobPayloads[N], jobId: string) => Promise<void>,
): Promise<void> => {
  await boss.work<JobPayloads[N]>(name, async (jobs) => {
    for (const job of jobs) {
      logger.info(
        { jobId: job.id, job: name, requestId: job.data.requestId },
        "job started",
      );
      await handler(job.data, job.id);
      logger.info({ jobId: job.id, job: name }, "job completed");
    }
  });
};
```

Job handlers live in `jobs/<feature>/<action>.job.ts`, are pure functions of
their payload (framework-free, like services), and are registered in
`worker.ts`:

```ts
// jobs/email/send-welcome.job.ts
import type { JobPayloads } from "#lib/queue.js";
import logger from "#utils/logger.js";

export const sendWelcomeEmail = async (
  payload: JobPayloads["email.send-welcome"],
): Promise<void> => {
  const { userId, requestId } = payload;
  logger.info({ userId, requestId }, "sending welcome email");
  // Call the mail module here; throw on failure so pg-boss retries.
};
```

## 12. app.ts skeleton

NOTE: security middleware (helmet, cors using `ENV.CORS_ACCESS`, rate
limiting) and its exact ordering are OWNED by the `security-hardening` skill.
Wire them where the comment marks; do not invent that config here or copy it
from memory.

```ts
import express from "express";
import cookieParser from "cookie-parser";
import HTTP_STATUS_CODES from "#constants/http-status-codes.js";
import { requestId } from "#middlewares/request-id.js";
import { errorHandler } from "#middlewares/error-handler.js";
import { NotFoundError } from "#utils/errors.js";
import prisma from "#lib/prisma.js";
import v1Routes from "#routes/index.js";

const app = express();

app.use(requestId); // first, so every later log line has the id

// >>> Security middleware block (helmet, cors, rate limits) goes here.
// >>> Configuration and ordering: see the security-hardening skill.

// 100kb JSON body cap: sane default for an API that never proxies file
// bytes. The full middleware order (and per-route overrides such as raw
// webhook bodies) is owned by the security-hardening skill.
app.use(express.json({ limit: "100kb" }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());

// Liveness: process is up. Readiness: dependencies reachable (503 keeps the
// platform from routing traffic before the DB answers).
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

app.use("/api/v1", v1Routes);

// Unmatched routes become a typed 404 through the same envelope.
app.use((req, _res, next) => {
  next(new NotFoundError(`Route ${req.method} ${req.originalUrl} not found`));
});

// Last. The only place error JSON is produced.
app.use(errorHandler);

export default app;
```

## 13. server.ts + worker.ts (graceful shutdown)

Both processes shut down the same way on SIGTERM/SIGINT: stop accepting,
drain in-flight work, close pg-boss, disconnect Prisma. The 10s force-exit
timer is `unref()`d so it never keeps an otherwise-finished process alive.

```ts
// server.ts
import { createServer } from "node:http";
import app from "#app.js";
import ENV from "#config/env.js";
import logger from "#utils/logger.js";
import prisma from "#lib/prisma.js";
import { boss, startQueue } from "#lib/queue.js";

const server = createServer(app);

const start = async (): Promise<void> => {
  await startQueue(); // enqueue-only here; handlers run in worker.ts
  server.listen(ENV.PORT, () => {
    logger.info({ port: ENV.PORT, env: ENV.NODE_ENV }, "API listening");
  });
};

let shuttingDown = false;

const shutdown = (signal: string): void => {
  if (shuttingDown) return; // a second signal must not re-run the sequence
  shuttingDown = true;
  logger.info({ signal }, "shutting down");

  const forceExit = setTimeout(() => {
    logger.error("shutdown timed out after 10s, forcing exit");
    process.exit(1);
  }, 10_000);
  forceExit.unref();

  server.close(async () => {
    try {
      await boss.stop({ graceful: true, wait: true });
      await prisma.$disconnect();
      logger.info("shutdown complete");
      process.exit(0);
    } catch (err) {
      logger.error({ err }, "error during shutdown");
      process.exit(1);
    }
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("unhandledRejection", (reason) => {
  logger.fatal({ err: reason }, "unhandled rejection");
  shutdown("unhandledRejection");
});

start().catch((err) => {
  logger.fatal({ err }, "failed to start");
  process.exit(1);
});
```

```ts
// worker.ts
import ENV from "#config/env.js";
import logger from "#utils/logger.js";
import prisma from "#lib/prisma.js";
import { boss, registerWorker, startQueue } from "#lib/queue.js";
import { sendWelcomeEmail } from "#jobs/email/send-welcome.job.js";

const start = async (): Promise<void> => {
  await startQueue();
  await registerWorker("email.send-welcome", sendWelcomeEmail);
  // Register every other job handler here.
  logger.info({ env: ENV.NODE_ENV }, "worker active");
};

let shuttingDown = false;

const shutdown = async (signal: string): Promise<void> => {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, "worker shutting down");

  const forceExit = setTimeout(() => {
    logger.error("worker shutdown timed out after 10s, forcing exit");
    process.exit(1);
  }, 10_000);
  forceExit.unref();

  try {
    await boss.stop({ graceful: true, wait: true }); // finish active jobs
    await prisma.$disconnect();
    logger.info("worker shutdown complete");
    process.exit(0);
  } catch (err) {
    logger.error({ err }, "error during worker shutdown");
    process.exit(1);
  }
};

process.on("SIGTERM", () => void shutdown("SIGTERM"));
process.on("SIGINT", () => void shutdown("SIGINT"));

start().catch((err) => {
  logger.fatal({ err }, "worker failed to start");
  process.exit(1);
});
```
