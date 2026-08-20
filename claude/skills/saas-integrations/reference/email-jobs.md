# Reference: Email + Background Jobs (pg-boss + Resend + React Email)

Read this before writing email-sending code, a job handler, or a schedule.
Two laws: email sending ALWAYS rides a pg-boss job, and every job payload is
typed through the ONE `JobPayloads` map in the scaffold's `src/lib/queue.ts`.

## The queue module is the scaffold's (src/lib/queue.ts)

`project-scaffold` owns the single queue module: `src/lib/queue.ts`, imported
as `#lib/queue.js` (canonical code: project-scaffold
`reference/backend-infra.md` section 11). It exports `boss`, `startQueue`, the
typed `enqueue`, the typed `registerWorker`, the `JobPayloads` map, and
`JOB_NAMES`. Never define a second PgBoss instance, a parallel payload map, or
another enqueue helper: this file only EXTENDS that module with integration
jobs.

pg-boss v10 requires `boss.createQueue(name)` for every queue before anything
sends to or works it. The scaffold's `startQueue()` (called at boot by both
`server.ts` and `worker.ts`) does exactly that for every name in `JOB_NAMES`,
so a job exists at runtime only once its name is in that array.

## Extending JobPayloads + JOB_NAMES (edit lib/queue.ts, never a new file)

Every job name is `"<feature>.<action>"` and appears in the map exactly once.
The scaffold's `enqueue` and `registerWorker` derive their types from the map,
so a payload mismatch fails at compile time. Add each new name to BOTH the
interface and `JOB_NAMES`: a name missing from `JOB_NAMES` never gets
`createQueue`d and fails at runtime on the first send.

```ts
// lib/queue.ts (scaffold module): extend these two exports in place
export interface JobPayloads {
  // ...entries the repo already has, e.g. "email.send-welcome"
  "email.payment-receipt": BaseJobPayload & { paymentId: string; reference: string };
  "email.password-reset": BaseJobPayload & { userId: string; token: string };
  "payments.reconcile": BaseJobPayload; // scheduled; no domain payload
  "media.orphan-sweep": BaseJobPayload; // scheduled; see reference/media.md
}

/** Keep in sync with JobPayloads; `satisfies` rejects unknown names. */
export const JOB_NAMES = [
  // ...existing names
  "email.payment-receipt",
  "email.password-reset",
  "payments.reconcile",
  "media.orphan-sweep",
] as const satisfies readonly JobName[];
```

`BaseJobPayload` (already in the module) carries the optional `requestId`
every payload needs for tracing across the queue hop. The scaffold's `enqueue`
applies the house retry policy (retryLimit 3, retryDelay 30s, exponential
backoff); pass its options parameter only when a job justifies overriding it.

## Email templates (React Email, one mail/ directory)

One component per template, typed props, no inline HTML strings in services.

```tsx
// mail/templates/payment-receipt.tsx
import { Html, Head, Body, Container, Heading, Text, Hr } from "@react-email/components";

export interface PaymentReceiptProps {
  recipientName: string;
  amountMinor: number;
  currency: string; // "GHS" etc.
  reference: string;
  paidAt: string; // ISO string; format inside the template
}

const formatMoney = (amountMinor: number, currency: string) =>
  new Intl.NumberFormat("en", { style: "currency", currency }).format(amountMinor / 100);
// Display is the ONLY place minor units become major units.

export const PaymentReceipt = (props: PaymentReceiptProps) => (
  <Html>
    <Head />
    <Body style={{ fontFamily: "sans-serif", backgroundColor: "#f6f6f6" }}>
      <Container style={{ backgroundColor: "#ffffff", padding: "24px" }}>
        <Heading as="h2">Payment received</Heading>
        <Text>Hi {props.recipientName},</Text>
        <Text>
          We received your payment of {formatMoney(props.amountMinor, props.currency)}.
        </Text>
        <Hr />
        <Text style={{ color: "#666", fontSize: "12px" }}>Reference: {props.reference}</Text>
      </Container>
    </Body>
  </Html>
);
```

## Template registry + typed enqueueEmail helper

```ts
// mail/templates/index.ts
import { PaymentReceipt, type PaymentReceiptProps } from "#mail/templates/payment-receipt.js";
import { Welcome, type WelcomeProps } from "#mail/templates/welcome.js";

export const EMAIL_TEMPLATES = {
  "payment-receipt": { component: PaymentReceipt, subject: (p: PaymentReceiptProps) => `Receipt ${p.reference}` },
  "welcome": { component: Welcome, subject: (_p: WelcomeProps) => "Welcome!" },
} as const;

export type TemplateName = keyof typeof EMAIL_TEMPLATES;
```

```ts
// mail/enqueue-email.ts
import { enqueue, type JobName, type JobPayloads } from "#lib/queue.js";

type EmailJobName = Extract<JobName, `email.${string}`>;

// Thin, typed wrapper over the scaffold's enqueue so call sites read as intent:
export const enqueueEmail = <N extends EmailJobName>(name: N, payload: JobPayloads[N]) =>
  enqueue(name, payload);
```

## The send handler: render + Resend, dev preview fallback

The handler resolves fresh data from the DB by id (payloads carry ids, not
whole documents: stale copies are a re-delivery bug). Handlers live at
`jobs/<feature>/<action>.job.ts` (scaffold layout) and take `(payload, jobId)`
in that order: the exact signature the scaffold's `registerWorker` calls.
Sending is naturally idempotent enough for receipts; for stricter cases see
the idempotency section.

```ts
// jobs/email/payment-receipt.job.ts
import { render } from "@react-email/render";
import { Resend } from "resend";
import { prisma } from "#lib/prisma.js";
import { ENV } from "#config/env.js";
import logger from "#utils/logger.js";
import { EMAIL_TEMPLATES } from "#mail/templates/index.js";
import type { JobPayloads } from "#lib/queue.js";

const resend = ENV.RESEND_API_KEY ? new Resend(ENV.RESEND_API_KEY) : null;

export const sendPaymentReceipt = async (
  payload: JobPayloads["email.payment-receipt"],
  jobId: string,
): Promise<void> => {
  const log = logger.child({ jobId, requestId: payload.requestId }); // ALWAYS jobId + requestId
  const payment = await prisma.payment.findUnique({
    where: { id: payload.paymentId },
    include: { donation: { include: { donor: true } } },
  });
  if (!payment || payment.status !== "SUCCESS") {
    log.warn({ paymentId: payload.paymentId }, "receipt skipped: payment missing or unsettled");
    return; // returning without throwing = job completes; do not retry a permanent condition
  }

  const template = EMAIL_TEMPLATES["payment-receipt"];
  const props = {
    recipientName: payment.donation?.donor.name ?? "there",
    amountMinor: payment.amountMinor,
    currency: payment.currency,
    reference: payment.reference,
    paidAt: payment.updatedAt.toISOString(),
  };
  const html = await render(template.component(props));

  if (!resend) {
    // Dev behavior: no RESEND_API_KEY means log/preview, never send.
    log.info({ to: payment.donation?.donor.email, subject: template.subject(props), html },
      "[dev] email preview (RESEND_API_KEY unset)");
    return;
  }

  const { error } = await resend.emails.send({
    from: ENV.EMAIL_FROM, // e.g. "App <no-reply@yourdomain.com>", typed ENV
    to: payment.donation!.donor.email,
    subject: template.subject(props),
    html,
  });
  if (error) throw new Error(`Resend failed: ${error.message}`); // throw => pg-boss retries
  log.info({ paymentId: payment.id }, "receipt sent");
};
```

ENV additions: `RESEND_API_KEY` via `envOptional` (unset in dev is legal and
means preview mode), `EMAIL_FROM` via `envRequired`.

Transactional only: receipts, resets, verifications, operational notices. Do
not build list management, campaign blasts, or unsolicited-mail machinery in
the app; that belongs in a dedicated ESP with consent handling.

SMS follows the same shape: one `services/sms/sms.service.ts` wrapping whichever
provider the design doc names, called only from job handlers (`sms.*` jobs).

## Worker registration (worker.ts)

Register handlers in the scaffold's `worker.ts` entrypoint through the typed
`registerWorker` from `#lib/queue.js`. It already iterates pg-boss v10's job
batches and logs `jobId` + `requestId` around every run; a handler that throws
is retried until `retryLimit`, then marked failed. The scaffold's queue module
also wires `boss.on("error", ...)`, so failure visibility needs no extra
plumbing here. Register every `JobPayloads` key: an unregistered job never
runs.

```ts
// worker.ts (scaffold entrypoint): the registration block inside start()
import { registerWorker, startQueue } from "#lib/queue.js";
import { sendPaymentReceipt } from "#jobs/email/payment-receipt.job.js";
import { reconcilePayments } from "#jobs/payments/reconcile.job.js";

await startQueue();
await registerWorker("email.payment-receipt", sendPaymentReceipt);
await registerWorker("payments.reconcile", reconcilePayments);
// register every other JobPayloads key here
```

`server.ts` also calls `startQueue()` but only enqueues; handlers run in the
worker process (same machine in dev, a separate service in production; see
the ci-cd skill's platform config).

## Scheduled jobs (cron via pg-boss)

```ts
// jobs/schedules.ts - called once in worker.ts, after the registerWorker calls
import { boss } from "#lib/queue.js";

export const registerSchedules = async () => {
  await boss.schedule("payments.reconcile", "0 2 * * *", {}, { tz: "UTC" }); // nightly 02:00 UTC
  await boss.schedule("media.orphan-sweep", "0 3 * * 0", {}, { tz: "UTC" }); // weekly
};
```

`schedule()` is idempotent per name: calling it at every boot updates the cron
in place. The handler is a normal registered worker, nothing special.

## Idempotent handler patterns (re-delivery WILL happen)

pg-boss delivers at-least-once: a crash after the effect but before the ack
re-runs the handler. Pick one of these per job:

1. **Natural idempotency**: the effect is a state-set, not an increment.
   `updateMany({ where: { id, status: "PENDING" }, data: { status: "SENT" } })`
   run twice converges to the same row.
2. **Check-before-effect**: read a marker first and bail.

```ts
// pattern 2, using a marker column on the domain row
const payment = await prisma.payment.findUnique({
  where: { id: payload.paymentId },
  select: { receiptSentAt: true },
});
if (payment?.receiptSentAt) return; // already done; re-delivery no-op

await sendTheEmail();
await prisma.payment.update({
  where: { id: payload.paymentId },
  data: { receiptSentAt: new Date() },
});
```

3. **Unique-key insert**: for "exactly one row per event" effects, insert with a
   unique constraint and swallow the P2002 duplicate error as a no-op.

Never increment counters or append rows in a handler without one of these.

## Enqueue placement rule

Services enqueue AFTER their `$transaction` commits (see settlePayment in
reference/payments.md). Enqueuing inside a transaction that later rolls back
sends email for work that never happened; enqueue-after-commit plus an
idempotent handler is the house tradeoff (a crash in the gap is caught by the
reconciliation/sweep jobs).
