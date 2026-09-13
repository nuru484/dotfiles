# Reference: Transactions, Concurrency & Soft Deletes

Read this before writing any multi-step database mutation or anything that
decrements a shared quantity (stock, seats, balance, remaining allocation).

## Interactive transactions

Use `prisma.$transaction(async (tx) => …)` whenever two or more writes must
succeed or fail together, or when a decision depends on a consistent read.

```ts
const result = await prisma.$transaction(async (tx) => {
  const donation = await tx.inKindDonation.findFirst({
    where: { id: input.inKindDonationId, deletedAt: null },
    select: { id: true, status: true, quantityRemaining: true /* ... */ },
  });
  if (!donation) throw new NotFoundError("In-kind donation not found");
  // ...invariant checks throwing typed errors...
  // ...guarded decrement (below)...
  return created;
});
```

Rules:
- Do **all** reads the decision depends on **inside** the same `tx`.
- Use the `tx` client for every query in the block - never the global `prisma`.
- Throw inside the callback when all writes should roll back. For a rejection that
  must persist writes (for example token revocation), return an outcome, await commit,
  then raise the HTTP error outside the transaction. Never set cookies or call external
  providers inside a transaction callback that can fail or retry.

## Pass `tx` to helpers - keep them pure and composable

A helper used inside a transaction takes the client as a parameter:

```ts
import type { TransactionClient } from "#lib/prisma.js";

export const assertRequestAcceptsStock = async (
  tx: TransactionClient,
  requestId: string,
): Promise<void> => {
  const request = await tx.donationRequest.findFirst({
    where: { id: requestId, deletedAt: null },
    select: { id: true, status: true },
  });
  if (!request) throw new NotFoundError("Donation request not found");
  if (request.status !== RequestStatus.APPROVED) {
    throw new BadRequestError("Stock can only be allocated to an APPROVED request");
  }
};
```

*Why:* the helper has no hidden dependency on a connection - it works in or out
of a transaction and is trivial to test by passing a fake/`tx` client.

`TransactionClient` (from `lib/prisma.ts`) preserves the soft-delete extension's
scoping through the type system:

```ts
export type TransactionClient = Omit<
  typeof prisma,
  "$connect" | "$disconnect" | "$on" | "$transaction" | "$use" | "$extends"
>;
```

## Concurrency: atomic guarded `updateMany`, never read-then-write

To decrement a shared quantity safely, put the guard in the `where` and check the
affected row count - do not read the value, compute in JS, then write it back.

```ts
const decremented = await tx.inKindDonation.updateMany({
  where: {
    id: donation.id,
    status: InKindStatus.COLLECTED,
    quantityRemaining: { gte: input.quantityAllocated }, // guard
  },
  data: { quantityRemaining: { decrement: input.quantityAllocated } },
});

if (decremented.count === 0) {
  // Lost the race or insufficient stock - neither is a successful path.
  throw new BadRequestError("Insufficient remaining stock for this allocation");
}
```

*Why:* the database enforces the invariant atomically. Two concurrent requests
can't both pass a stale "enough stock" check, because the `gte` guard and the
decrement happen in one statement.

## Soft deletes

Note on the examples above: they write `deletedAt: null` explicitly even
though the extension already scopes predicate reads. That is deliberate
defense-in-depth inside transactions (the invariant is visible at the call
site); outside transactions, verify exactly which operations and nested relations the
extension scopes; it is not an ownership or tenant-isolation boundary. Pick one style per repo and stay consistent.

- Models requiring recovery/history may carry `deletedAt: DateTime?`. "Delete" = set `deletedAt = new Date()`.
- The Prisma extension (`lib/soft-delete-extension.ts`) auto-scopes predicate
  reads (`findMany/findFirst(OrThrow)/count/aggregate/groupBy`) to `deletedAt: null`.
- `findUnique` is intentionally **not** scoped - it's the seam for finding a
  deleted row on purpose (reactivation, payment settlement, idempotency).
- To include deleted rows explicitly, mention `deletedAt` in the `where` yourself;
  the extension respects an explicit predicate (opt-out / opt-in).

```ts
// Normal read - deleted rows invisible automatically:
await tx.donor.findMany({ where: { campaignId } });

// Deliberate: settle/reactivate a soft-deleted row:
const donor = await tx.donor.findUnique({ where: { id }, select: { id: true, deletedAt: true } });
if (donor?.deletedAt) { /* reactivation is an explicit decision */ }
```

## Idempotency for external/payment operations

- Generate a unique transaction/idempotency reference for each donation/payment.
- On webhook/callback, look the record up with `findUnique` (the unscoped seam)
  and use an atomic guarded transition plus a unique key for settlement. A read-before-write
  check alone is not concurrency-safe. Persist required notifications via an outbox
  or proven transaction-aware queue integration.
