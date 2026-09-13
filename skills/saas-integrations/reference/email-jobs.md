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

const formatMoney = (amountMinor: number, currency: string) => {
  const formatter = new Intl.NumberFormat("en", { style: "currency", currency });
  const exponent = formatter.resolvedOptions().maximumFractionDigits ?? 2;
  return formatter.format(amountMinor / 10 ** exponent);
};
// Validate supported currencies and provider-specific minor-unit rules at the API boundary.
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

## The send handler: durable delivery + Resend

Handlers live at `jobs/<feature>/<action>.job.ts` and take `(payload, jobId)`
as the installed queue wrapper requires. Queue payloads identify a durable
outbox delivery. Resolve that delivery, rather than rebuilding a receipt from
mutable payment data on every retry.

Implement these steps against the application's schema:

1. Commit the business change and delivery intent together. Give the delivery a
   unique business-event key; validate the recipient and freeze the intended
   message data. Missing recipients require an explicit skipped/failed outcome.
2. Before the first provider call, persist the exact rendered request and a
   stable provider idempotency key. Retries reuse both, even after templates or
   donor details change. Protect stored message content as sensitive data and
   apply a retention policy.
3. Claim work using the project's concurrency/lease mechanism. A lease alone
   cannot prevent duplication after a send succeeds but the acknowledgement is
   lost. Use provider deduplication for that window.
4. Send the persisted request. This fragment assumes `delivery` is the claimed
   persisted record; it is not a complete database implementation:

```ts
const { data, error } = await resend.emails.send(
  delivery.request, // immutable { from, to, subject, html }
  { idempotencyKey: delivery.providerKey },
);
if (error) throw new Error(`Resend failed: ${error.message}`);
// Persist data.id and the accepted outcome before acknowledging the queue job.
// Classify permanent errors, retryable errors, and uncertain outcomes separately.
```

5. Record provider acceptance separately from confirmed recipient delivery.
   Handle provider delivery events if the product needs that distinction.
   Resend retains idempotency keys for 24 hours; after that window, an uncertain
   send needs reconciliation or an explicit duplicate-risk policy, not blind
   retry. Reusing a key with changed content is an error. Check the installed
   SDK signature and provider contract before adapting this fragment.

Source: [Resend idempotency keys](https://resend.com/docs/dashboard/emails/idempotency-keys).

In explicitly configured development preview mode, write a local preview only
when requested and log safe identifiers, not recipient addresses, reset tokens,
message bodies, or HTML. Do not mark a preview as a production send. Missing
`RESEND_API_KEY` in production is a configuration error; validate it at startup.
`EMAIL_FROM` must be a configured, verified sender.

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

## Delivery guarantees and retries

Queue delivery may repeat after a crash. Database-only effects can use atomic
conditional updates or unique event keys within a transaction. For external email,
a check-before-send marker is not enough: concurrent workers can both send, and a
crash after sending but before recording success can resend on retry.

Use a stable provider idempotency key when supported, record provider outcomes, and
reconcile uncertain sends according to the provider contract. A local job lease
prevents concurrent workers but cannot alone guarantee exactly-once external delivery.
Document that limitation and avoid claiming a sent marker proves deduplication.

## Enqueue placement

When an email is required by a committed state change, persist an outbox row in that
same transaction or use a queue API verified to share the database transaction.
A dispatcher retries durable outbox records and reconciles stuck work. Do not call
an ordinary enqueue/send API from a rollbackable callback, and do not rely on
post-commit enqueue alone: a crash between commit and enqueue loses the message.

Optional best-effort notifications can use post-commit enqueue only when their
possible loss is an explicit product decision. Reconciliation must actually exist
and cover those records before claiming it closes a delivery gap.

Test duplicate events, competing workers, rollback, crash after commit before enqueue,
and uncertain external sends. Keep tests isolated from real recipients.
