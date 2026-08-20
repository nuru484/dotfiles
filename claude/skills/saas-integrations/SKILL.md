---
name: saas-integrations
description: >-
  Provider integration playbook for the user's SaaS stack (Express 5 + TS ESM +
  Prisma + pg-boss backend, Next.js App Router frontend): payments and checkout
  (Paystack/Stripe), webhooks, transactional email (Resend + React Email), SMS,
  file/image/media upload and storage (Cloudinary signed uploads), and background
  jobs or scheduled tasks (pg-boss). Apply AUTOMATICALLY whenever implementing
  payments, checkout, or webhooks, sending email or SMS, handling file, image, or
  media upload or storage, or adding background jobs or scheduled tasks, in any app.
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
| Email | **Resend** + React Email templates | SMTP/nodemailer only when the design doc demands it. See `reference/email-jobs.md` |
| SMS | Provider named in the design doc | Always wrap behind one `sms.service` so the provider is swappable |
| Media | **Cloudinary** signed uploads | Client uploads direct to Cloudinary; API only signs. See `reference/media.md` |
| Jobs/queue | **pg-boss** | Already the house queue; no Redis/BullMQ unless the doc says so |

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
```

## Reference files

- `reference/payments.md`: Paystack end to end (ENV, Prisma model, initialize,
  webhook, settle, verify), Stripe variant, test-mode setup.
- `reference/email-jobs.md`: typed pg-boss queue, Resend handler, React Email
  templates, enqueueEmail helper, schedules, idempotency, worker registration.
- `reference/media.md`: Cloudinary signature endpoint, RTK Query direct upload,
  Media model, delete lifecycle, next/image usage.

Read the relevant reference file BEFORE writing payment, email, media, or job
code. If the design doc conflicts with a default here, the design doc wins;
the flow laws (signatures, idempotency, minor units, queue for I/O) never bend.
