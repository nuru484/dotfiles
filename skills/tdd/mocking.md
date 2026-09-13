# When to Mock

Mock at **system boundaries** only - things outside the code you own:

- External APIs and SDKs (payment provider, email service, cloud storage)
- Time and randomness (fake timers, injected clock/id generators)
- The network in frontend tests (use MSW: mock the HTTP layer, not your hooks)

Don't mock:

- Your own classes/modules/services
- Internal collaborators
- The database in integration tests (use the real test DB per harness.md:
  constraints, transactions, and the soft-delete extension are behavior
  you must verify). A narrow exception: a helper that takes a `tx`
  TransactionClient parameter may get a fake client in a focused unit test
  of that helper's branching; the flows that USE it still get real-DB tests.
- The filesystem, unless injecting failures; otherwise use a temp dir.

## Asserting on mocked boundaries is allowed (and often required)

When a true external is mocked, the observable behavior IS the call across
the boundary. Assert on it precisely:

```typescript
test("checkout charges the gateway exactly once with the cart total", async () => {
  const gateway = { charge: vi.fn().mockResolvedValue({ id: "ch_1", status: "succeeded" }) };
  await checkout(cart, gateway);
  expect(gateway.charge).toHaveBeenCalledExactlyOnceWith({ amountMinor: cart.totalMinor, currency: "GHS" });
});
```

This is not the anti-pattern from tests.md: that rule bans spying on YOUR
OWN internals. Double-charge prevention, exactly-once email sends, and
webhook idempotency can only be verified this way. Also test the failure
side: the gateway rejecting must produce the correct domain outcome (order
stays pending, typed error thrown), not a crash.

## Designing for Mockability

**1. Use dependency injection** - pass external dependencies in rather than
creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**2. Prefer SDK-style interfaces over generic fetchers** - specific functions
per external operation instead of one generic function:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```

The SDK approach means each mock returns one specific shape, no conditional
logic in test setup, and type safety per endpoint.
