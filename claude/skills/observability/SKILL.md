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
owns the error model). Secrets/PII *policy* → `security-hardening`; this skill
makes sure we never *log* them. Canonical logger/request-id middleware source →
`project-scaffold`.

## Self-audit checklist

```
LOGGING
[ ] Structured logs via pino (JSON in prod), never console.* in shipped code
[ ] Every log line carries requestId (and userId when authenticated)
[ ] Log levels used correctly: error=needs attention, warn=recoverable,
    info=lifecycle/business event, debug=dev detail
[ ] No secrets/PII in logs (passwords, tokens, full card/phone) - redacted

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
- Choose the level deliberately - the central error handler already routes by
  `severity`; mirror that intent everywhere (don't `error` a 404).
- **Never** log secrets or PII. Belt and braces: configure pino's built-in
  `redact` paths in the logger itself (`*.password`, `*.token`, `*.secret`,
  `req.headers.authorization`, `req.headers.cookie`, card/phone fields →
  `[REDACTED]`) so EVERY log call is protected, plus the error handler's
  context scrubbing for error payloads. A forgotten manual scrub must not be
  able to leak a token.

## Request correlation
- The mechanism (don't reinvent it per project): **pino-http** with
  `genReqId` (honor inbound `x-request-id`, else `crypto.randomUUID()`) gives
  every request a child logger (`req.log`) that stamps `requestId` on every
  line, and sets the response header. Code with no `req` in scope (services
  called from jobs, Prisma hooks) gets the id via an **AsyncLocalStorage**
  request context when needed - never by threading `requestId` through every
  function signature. Canonical code: `project-scaffold`.
- The error handler already mints an `errorId`; log both so a client error
  maps to a log line.
- Pass the `requestId` into any job enqueued during the request (a field in
  the typed job payload) so async work is traceable end to end.

## Error tracking
- Default tracker: **Sentry** (`SENTRY_DSN` via ENV; tracker inert when unset,
  so dev needs no account). Backend: init first in the entrypoint,
  `Sentry.setupExpressErrorHandler(app)` registered BEFORE the central
  errorHandler so both run. Frontend: `@sentry/nextjs` - the browser needs a
  production error sink too (the no-console rule removes the only other one).
- Send **unexpected** errors (unhandled rejections, 5xx, `severity: HIGH/CRITICAL`)
  with `requestId`, route, method, and **sanitized** context.
- Don't page on expected 4xx (`NotFoundError`, `ValidationError`) - log them and move on.
- Process-level handlers: report then **crash** on `uncaughtException` (the
  process state is undefined; the platform restarts it) and treat
  `unhandledRejection` the same. Never install a swallow-and-continue handler.

## Health & lifecycle
- `/health` returns 200 if the process is up (liveness).
- `/ready` checks dependencies (DB query, queue connection) and returns 503 when
  not ready, so the platform doesn't route traffic prematurely. Both live at the
  root, unversioned (platform probes need stable paths; exempt from `/api/v1`).
- On `SIGTERM`/`SIGINT`: stop accepting new work, finish in-flight requests/jobs,
  close pg-boss workers, `prisma.$disconnect()`, then exit - with a **forced-exit
  deadline** (`setTimeout(() => process.exit(1), 10_000).unref()`) so a hung
  request can't stall shutdown until the platform SIGKILLs mid-write. Mirror
  this in both the HTTP server and the worker process.

## Metrics & tracing (the rest of observability)
- **Minimum bar for every production app**: request duration/throughput/error
  rate. Expose `prom-client` default metrics + an HTTP duration histogram at
  `/metrics` when the platform can scrape, otherwise rely on the platform's
  built-in request metrics (Render/Heroku dashboards) plus Sentry performance
  sampling (`tracesSampleRate` ~0.1) so "is p95 degrading?" is answerable.
- **Distributed tracing (OpenTelemetry)** is deliberately deferred until there
  are multiple services; a monolith + worker gets what it needs from
  requestId correlation + Sentry. Record the decision, don't drift into it.

## Post-launch operations (production-grade is not just code)
- **Backups**: managed Postgres daily snapshots ON, and verify a restore once
  (a backup that has never been restored is a hope, not a backup).
- **Uptime**: an external ping on `/ready` (UptimeRobot/healthchecks.io tier is
  fine) alerting to email/phone.
- **Alert routing**: pages for 5xx spikes and readiness failures; logs for the rest.

## When unsure
If you can't answer "when this breaks at 2am, what will the logs show?" for a
change, add the missing requestId/context/level before shipping it.
