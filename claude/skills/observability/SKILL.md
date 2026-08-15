---
name: observability
description: >-
  Conventions for logging, request correlation, error tracking, health checks,
  and graceful lifecycle in the user's Node/Express backends and pg-boss workers.
  Apply AUTOMATICALLY when adding logging, wiring an error tracker, writing a
  health/readiness endpoint, handling process signals/shutdown, or instrumenting
  a request or job. Use whenever the task is about knowing what the system is doing
  in production.
---

# Observability Conventions

How the running system explains itself. Pairs with `backend-conventions` (which
owns the error model). Secrets/PII *policy* → security skill; this skill makes sure
we never *log* them.

## Self-audit checklist

```
LOGGING
[ ] Structured logs via pino (JSON in prod), never console.* in shipped code
[ ] Every log line carries requestId (and userId when authenticated)
[ ] Log levels used correctly: error=needs attention, warn=recoverable,
    info=lifecycle/business event, debug=dev detail
[ ] No secrets/PII in logs (passwords, tokens, full card/phone) — redacted

CORRELATION
[ ] A requestId is generated/propagated per request and returned to the client
[ ] Background jobs log their job id + the originating requestId when available

ERROR TRACKING
[ ] Unhandled + 5xx errors reported to an error tracker (e.g. Sentry) with
    requestId, route, and sanitized context
[ ] 4xx (expected) errors are logged, not paged

LIFECYCLE
[ ] /health (liveness) and /ready (DB/queue reachable) endpoints exist
[ ] SIGTERM/SIGINT: stop accepting, drain in-flight, close queue, prisma.$disconnect()
[ ] Worker logs "active" on boot and closes workers on shutdown
```

## Structured logging (pino)
- One logger (`utils/logger.ts`); `pino-pretty` in dev, JSON in prod.
- Log **objects, not interpolated strings**: `logger.info({ requestId, donationId }, "donation created")`.
- Choose the level deliberately — the central error handler already routes by
  `severity`; mirror that intent everywhere (don't `error` a 404).
- **Never** log secrets or PII. Reuse the error handler's redaction approach
  (`password`, `token`, `secret`, `key`, `auth`, card, full phone → `[REDACTED]`).

## Request correlation
- Generate a `requestId` per request (or honor an inbound `x-request-id`), attach
  it to the request, every log line, and the response header. The error handler
  already mints an `errorId`; tie them together so a client error maps to a log.
- Pass the `requestId` into any job enqueued during the request so async work is
  traceable end to end.

## Error tracking
- Send **unexpected** errors (unhandled rejections, 5xx, `severity: HIGH/CRITICAL`)
  to an error tracker with `requestId`, route, method, and **sanitized** context.
- Don't page on expected 4xx (`NotFoundError`, `ValidationError`) — log them and move on.

## Health & lifecycle
- `/health` returns 200 if the process is up (liveness).
- `/ready` checks dependencies (DB query, queue connection) and returns 503 when
  not ready, so the platform doesn't route traffic prematurely.
- On `SIGTERM`/`SIGINT`: stop accepting new work, finish in-flight requests/jobs,
  close pg-boss workers, `prisma.$disconnect()`, then exit. Mirror this in both the
  HTTP server and the worker process.

## When unsure
If you can't answer "when this breaks at 2am, what will the logs show?" for a
change, add the missing requestId/context/level before shipping it.
