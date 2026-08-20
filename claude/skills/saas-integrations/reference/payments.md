# Reference: Payments (Paystack default, Stripe variant)

Read this before writing any payment, checkout, or payment-webhook code.
Paystack is the default for GHS/NGN/ZAR/KES; Stripe for everything else.
Both follow the SAME local flow: our unique reference, local PENDING row first,
webhook as source of truth, idempotent settlement in a transaction.

Money is integer minor units everywhere. Paystack's `amount` field is ALREADY
minor units (pesewas for GHS, kobo for NGN), so `amountMinor` passes straight
through: no multiplication, no division, no floats.

## ENV additions (config/env.ts)

```ts
export const ENV = {
  // ...existing vars
  PAYSTACK_SECRET_KEY: envRequired("PAYSTACK_SECRET_KEY"), // sk_test_... in dev
  // envOptional takes ONE argument; defaults are applied with ?? (house helper contract)
  PAYSTACK_BASE_URL: envOptional("PAYSTACK_BASE_URL") ?? "https://api.paystack.co",
  FRONTEND_URL: envRequired("FRONTEND_URL"), // callback/redirect target
  // Stripe projects instead use:
  // STRIPE_SECRET_KEY: envRequired("STRIPE_SECRET_KEY"),        // sk_test_... in dev
  // STRIPE_WEBHOOK_SECRET: envRequired("STRIPE_WEBHOOK_SECRET"),// whsec_...
};
```

## Prisma model sketch

```prisma
enum PaymentStatus {
  PENDING
  SUCCESS
  FAILED
}

model Payment {
  id          String        @id @default(cuid())
  reference   String        @unique            // WE generate this; idempotency key
  amountMinor Int                              // pesewas/kobo/cents; NEVER float
  currency    String                           // "GHS", "NGN", "USD", ...
  status      PaymentStatus @default(PENDING)
  provider    String                           // "paystack" | "stripe"
  providerRef String?                          // provider's own id (Paystack id / Stripe pi_...)
  metadata    Json?
  // relation to the domain entity this payment settles, e.g.:
  donationId  String?
  donation    Donation?     @relation(fields: [donationId], references: [id])
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt
  deletedAt   DateTime?                        // house soft-delete convention

  @@index([status, createdAt])                 // reconciliation scans PENDING by age
}
```

## Reference generation (utils/payment-reference.ts)

```ts
import { randomBytes } from "node:crypto";

export const generateTransactionReference = (prefix: string): string =>
  `${prefix}_${Date.now()}_${randomBytes(6).toString("hex")}`;
// e.g. "don_1755640000000_a1b2c3d4e5f6" - unique, sortable, greppable
```

## Initialize service (services/payments/paystack.service.ts)

```ts
import { prisma } from "#lib/prisma.js";
import { ENV } from "#config/env.js";
import { BadRequestError, InternalServerError } from "#utils/errors.js";
import { generateTransactionReference } from "#utils/payment-reference.js";

interface InitializePaymentInput {
  actorId: string;
  email: string;
  amountMinor: number;   // already minor units; validated positive int by Zod
  currency: string;      // "GHS" etc.
  donationId: string;    // the domain entity being paid for
}

export const initializePayment = async (input: InitializePaymentInput) => {
  if (!Number.isInteger(input.amountMinor) || input.amountMinor <= 0) {
    throw new BadRequestError("amountMinor must be a positive integer");
  }
  const reference = generateTransactionReference("don");

  // 1. Local PENDING row FIRST, so a webhook can never race an unknown reference.
  const payment = await prisma.payment.create({
    data: {
      reference,
      amountMinor: input.amountMinor,
      currency: input.currency,
      provider: "paystack",
      donationId: input.donationId,
      metadata: { createdById: input.actorId },
    },
  });

  // 2. Then ask Paystack for a checkout URL. amount is minor units as-is.
  const res = await fetch(`${ENV.PAYSTACK_BASE_URL}/transaction/initialize`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${ENV.PAYSTACK_SECRET_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      email: input.email,
      amount: input.amountMinor,
      currency: input.currency,
      reference,
      callback_url: `${ENV.FRONTEND_URL}/payments/callback`,
      metadata: { donationId: input.donationId },
    }),
  });
  const body = (await res.json()) as {
    status: boolean;
    data?: { authorization_url: string; access_code: string };
    message?: string;
  };
  if (!res.ok || !body.status || !body.data) {
    await prisma.payment.update({
      where: { id: payment.id },
      data: { status: "FAILED", metadata: { failReason: body.message ?? "initialize failed" } },
    });
    throw new InternalServerError("Payment initialization failed", { context: { reference } });
  }

  return { reference, authorizationUrl: body.data.authorization_url };
};
```

Controller returns the house envelope:
`res.status(HTTP_STATUS_CODES.CREATED).json({ message: "Payment initialized", data })`.
The client redirects the browser to `authorizationUrl`. The client NEVER sends
an amount the server did not derive itself (look the price up server-side).

## Webhook route: raw body + HMAC-SHA512

Full path: `POST /api/v1/webhooks/paystack`. Mount the router in `app.ts`
BEFORE `app.use(express.json())` (`app.use("/api/v1", paystackWebhookRouter)`)
and use `express.raw` on the route, so `req.body` is the exact bytes Paystack
sent. The signature is computed over those bytes; a re-parsed and
re-stringified body will not match.

```ts
// routes/webhooks/paystack-webhook-routes.ts
import { Router, raw } from "express";
import { createHmac, timingSafeEqual } from "node:crypto";
import { ENV } from "#config/env.js";
import { settlePayment } from "#services/payments/settle-payment.service.js";
import logger from "#utils/logger.js";

export const paystackWebhookRouter = Router();

// app.ts mounts this router at /api/v1 BEFORE express.json(), so the raw
// Buffer reaches this route untouched: POST /api/v1/webhooks/paystack.
paystackWebhookRouter.post(
  "/webhooks/paystack",
  raw({ type: "application/json" }), // req.body is a Buffer here
  async (req, res) => {
    const signature = req.header("x-paystack-signature") ?? "";
    const expected = createHmac("sha512", ENV.PAYSTACK_SECRET_KEY)
      .update(req.body) // the raw Buffer, untouched
      .digest("hex");
    const sigBuf = Buffer.from(signature);
    const expBuf = Buffer.from(expected);
    if (sigBuf.length !== expBuf.length || !timingSafeEqual(sigBuf, expBuf)) {
      return res.sendStatus(401); // do not reveal why
    }

    const event = JSON.parse(req.body.toString("utf8")) as {
      event: string;
      data: { reference: string; id: number; status: string; amount: number; currency: string };
    };

    try {
      if (event.event === "charge.success") {
        await settlePayment({
          reference: event.data.reference,
          providerRef: String(event.data.id),
          providerAmountMinor: event.data.amount,
          providerCurrency: event.data.currency,
        });
      }
      // Paystack emits charge.success only; there is NO failure webhook for
      // card charges. Failed/abandoned charges are found via the verify
      // endpoint and the nightly reconciliation job, which call failPayment.
      // Unknown/other events: acknowledge and ignore.
      return res.sendStatus(200); // fast 200; heavy work is queued inside settlePayment
    } catch (err) {
      logger.error({ err, reference: event.data?.reference }, "paystack webhook failed");
      return res.sendStatus(500); // Paystack retries on non-2xx
    }
  },
);
```

## Settle service: idempotent, transactional (services/payments/settle-payment.service.ts)

```ts
import { prisma } from "#lib/prisma.js";
import { NotFoundError, BadRequestError } from "#utils/errors.js";
import { enqueueEmail } from "#mail/enqueue-email.js"; // see reference/email-jobs.md

interface SettlePaymentInput {
  reference: string;
  providerRef: string;
  providerAmountMinor: number;
  providerCurrency: string;
}

export const settlePayment = async (input: SettlePaymentInput) => {
  // findUnique deliberately bypasses the soft-delete scope: settle even if hidden.
  const payment = await prisma.payment.findUnique({ where: { reference: input.reference } });
  if (!payment) throw new NotFoundError(`Unknown payment reference ${input.reference}`);

  // Idempotency: providers re-deliver webhooks. Already settled means no-op.
  if (payment.status === "SUCCESS") return payment;

  // Integrity: the provider must have charged what we recorded.
  if (
    input.providerAmountMinor !== payment.amountMinor ||
    input.providerCurrency !== payment.currency
  ) {
    throw new BadRequestError("Provider amount/currency mismatch", {
      context: { reference: payment.reference },
    });
  }

  const settled = await prisma.$transaction(async (tx) => {
    // Guarded update: only one concurrent webhook delivery can win the flip.
    const { count } = await tx.payment.updateMany({
      where: { id: payment.id, status: "PENDING" },
      data: { status: "SUCCESS", providerRef: input.providerRef },
    });
    if (count === 0) return null; // another delivery settled it first: no-op

    // Domain effect lives in the SAME transaction as the status flip.
    if (payment.donationId) {
      await tx.donation.update({
        where: { id: payment.donationId },
        data: { status: "COMPLETED" },
      });
    }
    return tx.payment.findUniqueOrThrow({ where: { id: payment.id } });
  });
  if (!settled) return payment; // lost the race; treat as already settled

  // Side effects AFTER commit, via the queue. Never inline email in a webhook.
  await enqueueEmail("email.payment-receipt", {
    paymentId: settled.id,
    reference: settled.reference,
  });
  return settled;
};

export const failPayment = async (input: { reference: string }) => {
  await prisma.payment.updateMany({
    where: { reference: input.reference, status: "PENDING" }, // never demote SUCCESS
    data: { status: "FAILED" },
  });
};
```

## Verify endpoint (client polls after redirect)

The redirect/callback page reads status; it never settles. If the webhook is
slow, optionally confirm with the provider, then settle through the SAME
`settlePayment` path (idempotency makes double entry safe).

```ts
// services/payments/verify-payment.service.ts
export const verifyPayment = async (reference: string) => {
  const payment = await prisma.payment.findUnique({
    where: { reference },
    select: { reference: true, status: true, amountMinor: true, currency: true },
  });
  if (!payment) throw new NotFoundError("Payment not found");
  if (payment.status !== "PENDING") return payment;

  // Fallback: ask Paystack directly (covers a delayed webhook).
  const res = await fetch(`${ENV.PAYSTACK_BASE_URL}/transaction/verify/${reference}`, {
    headers: { Authorization: `Bearer ${ENV.PAYSTACK_SECRET_KEY}` },
  });
  const body = (await res.json()) as {
    status: boolean;
    data?: { status: string; id: number; amount: number; currency: string };
  };
  if (body.status && body.data?.status === "success") {
    const settled = await settlePayment({
      reference,
      providerRef: String(body.data.id),
      providerAmountMinor: body.data.amount,
      providerCurrency: body.data.currency,
    });
    return { reference, status: settled.status, amountMinor: settled.amountMinor, currency: settled.currency };
  }
  if (body.status && body.data?.status === "failed") {
    // The only failure signal Paystack gives (no failure webhook exists).
    await failPayment({ reference }); // guarded update: never demotes SUCCESS
    return { ...payment, status: "FAILED" as const };
  }
  return payment; // still PENDING/abandoned; the reconciliation job re-checks
};
```

Route: `GET /payments/:reference/verify`, authed, returns
`{ message: "Payment status", data: { reference, status, amountMinor, currency } }`.

## Reconciliation job (nightly)

The handler takes `(payload, jobId)`: the signature the scaffold's
`registerWorker` calls. Registration lives in `worker.ts`
(`await registerWorker("payments.reconcile", reconcilePayments)`; see
reference/email-jobs.md).

```ts
// jobs/payments/reconcile.job.ts   (scaffold layout: jobs/<feature>/<action>.job.ts)
// schedule: await boss.schedule("payments.reconcile", "0 2 * * *", {}, { tz: "UTC" });
import type { JobPayloads } from "#lib/queue.js";

export const reconcilePayments = async (
  _payload: JobPayloads["payments.reconcile"],
  jobId: string,
): Promise<void> => {
  const stuck = await prisma.payment.findMany({
    where: { status: "PENDING", createdAt: { lt: new Date(Date.now() - 30 * 60 * 1000) } },
    select: { reference: true },
    take: 200,
  });
  logger.info({ jobId, count: stuck.length }, "reconciling stuck payments");
  for (const { reference } of stuck) {
    await verifyPayment(reference); // settles, fails, or leaves pending; idempotent
  }
};
```

## Stripe variant (non-GHS/NGN/ZAR/KES currencies)

Same local flow; only the provider calls change.

```ts
import Stripe from "stripe";
const stripe = new Stripe(ENV.STRIPE_SECRET_KEY);

// Initialize: create local PENDING row (same as above), then a PaymentIntent.
const intent = await stripe.paymentIntents.create({
  amount: input.amountMinor,            // Stripe is minor units too
  currency: input.currency.toLowerCase(),
  metadata: { reference },              // OUR reference travels in metadata
});
// Persist intent.id as providerRef now; return intent.client_secret to the
// client for Stripe Elements / Checkout.
```

```ts
// Webhook: express.raw({ type: "application/json" }) on the route, then:
const event = stripe.webhooks.constructEvent(
  req.body,                              // raw Buffer
  req.header("stripe-signature") ?? "",
  ENV.STRIPE_WEBHOOK_SECRET,
); // throws on a bad signature: catch and respond 400

if (event.type === "payment_intent.succeeded") {
  const pi = event.data.object as Stripe.PaymentIntent;
  await settlePayment({
    reference: pi.metadata.reference,
    providerRef: pi.id,
    providerAmountMinor: pi.amount,
    providerCurrency: pi.currency.toUpperCase(),
  });
} else if (event.type === "payment_intent.payment_failed") {
  const pi = event.data.object as Stripe.PaymentIntent;
  await failPayment({ reference: pi.metadata.reference });
}
res.sendStatus(200);
```

`settlePayment`, `failPayment`, verify, and reconciliation are shared unchanged.

## Test mode

- **Paystack:** use `sk_test_...` in dev/staging ENV. Test cards from the
  Paystack docs (e.g. 4084 0840 8408 4081). Webhooks locally: expose the API
  (port 4000, per the port conventions) with a tunnel (e.g. `ngrok http 4000`)
  and set the webhook URL in the Paystack dashboard to
  `<tunnel-url>/api/v1/webhooks/paystack` (test mode has its own URL slot), or
  POST recorded payloads with a correctly computed HMAC in integration tests.
- **Stripe:** `sk_test_...` plus
  `stripe listen --forward-to localhost:4000/api/v1/webhooks/stripe`
  (the CLI prints the `whsec_...` for STRIPE_WEBHOOK_SECRET). Test card 4242 4242 4242 4242.
- Never mix live and test keys in one environment; keys come only from typed ENV.
- Tests to write first (house TDD rule: money always gets tests): duplicate
  webhook delivery settles once; tampered signature is rejected; amount
  mismatch refuses settlement; verify endpoint never flips FAILED to SUCCESS.
