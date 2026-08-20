---
name: saas-integrations
description: >-
  Provider integration playbook for the user's SaaS stack (Express 5 + TS ESM +
  Prisma + pg-boss backend, Next.js App Router frontend): payments and checkout
  (Paystack/Stripe), webhooks, transactional email (Resend + React Email), SMS,
  file/image/media upload and storage (Cloudinary signed uploads), background
  jobs or scheduled tasks (pg-boss), and realtime or in-app notifications
  (polling, SSE, socket.io). Apply AUTOMATICALLY whenever implementing
  payments, checkout, subscriptions, or webhooks, sending email or SMS, handling
  file, image, or media upload or storage, adding background jobs or scheduled
  tasks, building data export/import (CSV) or account deletion, or adding
  realtime updates, live feeds, or notification bells, in any app.
---

# SaaS Integrations

Provider choices and flow laws for external integrations. Follows the house
conventions (layering, typed ENV, CustomError, `{ message, data }` envelope,
soft deletes, pg-boss). **Money is ALWAYS an integer in minor units plus a
currency column (pesewas, kobo, cents). Never floats, never major units.**
*Why:* floats corrupt sums; minor-unit integers are what providers charge in.

## Provider decision table

Defaults exist so an unattended build never guesses. Override only when the
design doc names a different provider.

| Concern | Default provider | Rule |
| --- | --- | --- |
| Payments | **Paystack** when currency is GHS/NGN/ZAR/KES; **Stripe** otherwise | Keys from typed ENV; test keys in dev. See `reference/payments.md` |
| Subscriptions | **Stripe Billing** on Stripe; **Paystack Plans + Subscriptions** on Paystack | Provider-managed, webhook-driven; NEVER hand-rolled renewal crons. See `reference/payments.md` |
| Email | **Resend** + React Email templates | SMTP/nodemailer only when the design doc demands it. See `reference/email-jobs.md` |
| SMS | Provider named in the design doc | Always wrap behind one `sms.service` so the provider is swappable |
| Media | **Cloudinary** signed uploads | Client uploads direct to Cloudinary; API only signs. See `reference/media.md` |
| Jobs/queue | **pg-boss** | Already the house queue; no Redis/BullMQ unless the doc says so |
| Realtime / in-app notifications | **RTK Query polling** (15-30s); SSE only for sub-5s one-way; socket.io only for bidirectional | Notifications persist in the DB (source of truth). See `reference/realtime.md` |

*Why:* Paystack covers mobile money and cards in the markets the user serves
(often Ghana, GHS); Stripe covers the rest of the world; one queue and one
mail path keep operational surface small.

## Payment flow law (provider-agnostic)

Every payment feature follows this exact sequence. Full code: `reference/payments.md`.

1. **Initialize server-side** with a unique `transactionReference` WE generate
   (`@unique` in Prisma). Create the local `PENDING` row first, then call the
   provider. *Why:* our reference is the idempotency key and the join between
   provider and local records.
2. **Client redirects to checkout** using the provider URL/client secret we
   return. The client never sets amounts. *Why:* amounts from the client are
   attacker-controlled.
3. **The provider webhook is the SOURCE OF TRUTH for settlement.** Never the
   client redirect/callback page. *Why:* redirects get dropped, replayed, and
   forged; webhooks are signed.
4. **Verify the webhook signature on the RAW body** (`express.raw` on that
   route only, before any JSON parser touches it). *Why:* re-serialized JSON
   breaks HMAC comparison and unsigned webhooks are trivially spoofed.
5. **Look up by reference with `findUnique`; no-op if already settled.**
   *Why:* providers re-deliver webhooks; settlement must be idempotent.
6. **Settle inside `prisma.$transaction`:** update the payment AND apply the
   domain effect (mark order paid, credit donation, activate plan) together.
   *Why:* a paid payment with an unfulfilled domain effect is the worst bug class.
7. **Respond 200 fast; offload receipts/emails to pg-boss.** *Why:* slow
   webhook handlers time out and trigger provider retries.
8. **Expose a verify endpoint** the client polls after redirect to learn status.
   *Why:* the redirect page must read status, not write it.
9. **Reconcile nightly:** a scheduled job compares provider records to local
   `PENDING` payments older than a threshold and settles or fails them.
   *Why:* webhooks occasionally never arrive; reconciliation is the safety net.

## Email rules

- **All email SENDING goes through a pg-boss job.** Never call Resend inline in
  a request handler. *Why:* mail providers are slow and flaky; the queue gives
  retries and keeps request latency flat.
- One typed payload per template in the `JobPayloads` map; templates live in one
  `mail/` directory as React Email components.
- Dev behavior: when `RESEND_API_KEY` is unset, log/preview the rendered email
  instead of sending. *Why:* dev must never email real users.
- Transactional email only (receipts, resets, notifications). Never build bulk
  marketing/spam machinery in the app.
- Full code: `reference/email-jobs.md`.

## Media rules

- Client uploads **DIRECTLY to Cloudinary** using short-lived signed params from
  our API. Never proxy file bytes through Express. *Why:* streaming uploads
  through the API burns memory/bandwidth and adds a failure hop.
- The signature endpoint requires auth and constrains folder, allowed formats,
  and max bytes. *Why:* an unconstrained signature is an open upload endpoint.
- Store `publicId` + `width`/`height` + `bytes` + `format`; derive URLs at
  render time with `f_auto,q_auto`. *Why:* stored URLs rot when transforms change.
- Deletion lifecycle: soft delete rows like everything else; `destroy` on
  Cloudinary only at hard delete; run an orphan-sweep job for uploads that never
  got attached to a record.
- Next.js: `next/image` with a Cloudinary loader (or `f_auto,q_auto` URLs) and a
  real `sizes` attribute.
- Full code: `reference/media.md`.

## Jobs rules

- Job names are `"<feature>.<action>"`, e.g. `"email.donation-receipt"`,
  `"payments.reconcile"`. *Why:* greppable, self-describing queue names.
- One `JobPayloads` interface maps every job name to its payload type; `enqueue`
  and `work` are typed by it. *Why:* the queue boundary is where type safety
  usually dies; the map keeps it.
- **Handlers are idempotent.** pg-boss re-delivers after crashes; check-before-
  effect or naturally idempotent writes.
- Default retry: `retryLimit: 3`, exponential backoff (`retryBackoff: true`).
- Schedules via `boss.schedule(name, cron)`; handler is a normal worker.
- Every handler logs `jobId` and, when the payload carries one, `requestId`.
  *Why:* traces a user action end to end across the queue hop.
- Failure visibility: log dead-lettered/failed jobs (`retryLimit` exhausted) at
  error severity so they page someone instead of vanishing.
- Full code: `reference/email-jobs.md`.

## Data lifecycle rules (exports, imports, account deletion)

- **Small exports** (<= ~10k rows, seconds of work): synchronous CSV stream
  with `Content-Disposition: attachment`; the ONE sanctioned non-envelope
  success response (recorded in api-contracts). **Large exports:** pg-boss job
  + an ExportTask row; `POST` returns `202 { message, data: task }`, the
  client polls. This Task-with-status pattern is THE house convention for ALL
  long-running user-visible jobs (imports, report generation, bulk ops).
- **Imports:** the file rides the existing signed-upload path (never through
  `express.json`; the 100kb body cap is deliberate); a pg-boss job streams,
  parses, validates each row against the SAME Zod schemas the API uses, and
  stores a per-row error report on the task.
- **CSV both directions:** RFC 4180 quoting, UTF-8 BOM for Excel, ISO dates,
  money as decimal-plus-currency columns (exports are for people; the API and
  DB stay integer minor units).
- **Account deletion / PII erasure:** soft delete is for BUSINESS records;
  personal data gets a real erasure path: grace period (default 14 days,
  reversible), then a pg-boss job hard-scrubs through ONE erasure service.
- Full code: `reference/data-lifecycle.md`.

## Realtime & in-app notifications

- **Decision ladder - escalate only when the spec demands it:** (1) DEFAULT:
  RTK Query polling (`pollingInterval` 15-30s on the visible surface,
  `skipPollingIfUnfocused`) for notification bells, dashboards, job status;
  (2) SSE for one-way sub-5s feeds: normal `authenticateJWT` on the same
  cookie, heartbeat every 25s, origin verified, exempt from the global rate
  limiter, drained on SIGTERM; (3) socket.io ONLY for bidirectional (chat,
  collaborative editing): handshake cookie auth + explicit origin check
  (WS ignores CORS). Start single-instance; document the upgrade path.
- **Fan-out: the DB is the source of truth.** A Notification model written
  inside the domain transaction; SSE/sockets publish AFTER commit and only
  nudge; polling and reconnects read the table. Mark-read is PATCH; list
  responses carry `summary.unreadCount` per api-contracts.
- The backend `notifications/` folder owns this surface: `notification.service.ts`,
  `notification-query.service.ts`, routes + SSE route, `sse-registry.ts`.
- Full code and the critical infra interactions: `reference/realtime.md`.

## Self-audit checklist - run against every integration change

```
PAYMENTS
[ ] Reference generated by us, @unique in Prisma, used as idempotency key
[ ] Webhook signature verified on the RAW body (express.raw on that route)
[ ] Settlement: findUnique by reference, no-op if already SUCCESS
[ ] Settle + domain effect inside one $transaction
[ ] Amounts are integer minor units + currency column, everywhere (DB, API, provider)
[ ] Client never sets amount; verify endpoint reads, never writes
[ ] Reconciliation job exists for stuck PENDING payments
[ ] Subscription access flips only on webhook-verified events (no renewal crons); entitlements via one requirePlan + PLAN_LIMITS

EMAIL / SMS
[ ] No inline provider calls in request handlers: enqueue a pg-boss job
[ ] Payload typed per template in JobPayloads
[ ] Dev without RESEND_API_KEY logs/previews instead of sending
[ ] SMS wrapped behind one sms.service

MEDIA
[ ] Upload goes client -> Cloudinary directly with a signed request
[ ] Signature endpoint authed + validates type/size/folder
[ ] DB stores publicId/dimensions/bytes, not full URLs
[ ] Hard-delete destroys the Cloudinary asset; orphan sweep scheduled

JOBS
[ ] Names are <feature>.<action>; payloads typed via JobPayloads
[ ] Handlers idempotent under re-delivery
[ ] retryLimit 3 + exponential backoff unless justified otherwise
[ ] Handler logs jobId (+ requestId when present); failures logged loudly

DATA LIFECYCLE
[ ] Long-running export/import runs as a pg-boss job with a Task row (202 + poll), never in-request
[ ] Import files ride the signed-upload path; rows validated with the same Zod schemas as the API
[ ] CSV: RFC 4180 quoting, UTF-8 BOM, ISO dates, decimal money + currency column
[ ] Account deletion: grace period, then the ONE erasure service hard-scrubs PII

REALTIME
[ ] Polling is the default; SSE/socket.io only where the spec demands the freshness
[ ] Notification rows created inside the domain transaction; publish only after commit
[ ] SSE: authenticateJWT on the stream, heartbeat, global-limiter exemption, SIGTERM drain
[ ] socket.io: handshake cookie auth + origin check; single-instance constraint recorded
```

## Reference files

- `reference/payments.md`: Paystack end to end (ENV, Prisma model, initialize,
  webhook, settle, verify), Stripe variant, subscriptions & recurring billing
  (Stripe Billing / Paystack Plans, entitlements, dunning), test-mode setup.
- `reference/email-jobs.md`: typed pg-boss queue, Resend handler, React Email
  templates, enqueueEmail helper, schedules, idempotency, worker registration.
- `reference/media.md`: Cloudinary signature endpoint, RTK Query direct upload,
  Media model, delete lifecycle, next/image usage.
- `reference/data-lifecycle.md`: CSV exports (sync stream + Task-with-status
  jobs), imports with per-row error reports, CSV rules, account deletion &
  PII erasure.
- `reference/realtime.md`: the polling/SSE/socket.io decision ladder, the
  Notification model and API contract, the notifications/ folder layout, SSE
  route + registry with rate-limiter and graceful-shutdown interactions,
  socket.io handshake auth and scale-out constraints.

Read the relevant reference file BEFORE writing payment, subscription, email,
media, job, data-lifecycle (export/import/deletion), or realtime/notification
code. If the design doc conflicts with a default here, the design doc wins;
the flow laws (signatures, idempotency, minor units, queue for I/O) never bend.
