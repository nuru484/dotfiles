# Good and Bad Tests

## Good Tests

**Integration-style**: Test through real interfaces, not mocks of internal parts.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics:

- Tests behavior users/callers care about
- Uses public API only
- Survives internal refactors
- Describes WHAT, not HOW
- One logical assertion per test

## Bad Tests

**Implementation-detail tests**: Coupled to internal structure.

```typescript
// BAD: asserts on an INTERNAL collaborator instead of the outcome.
// checkout's contract is "the order is confirmed", not "it calls process()".
test("checkout calls paymentService.process", async () => {
  const processSpy = vi.spyOn(paymentService, "process");
  await checkout(cart, payment);
  expect(processSpy).toHaveBeenCalledWith(cart.total);
});
```

Red flags:

- Mocking your own modules/collaborators (see mocking.md for the boundary rule)
- Testing private methods
- Asserting call counts/order on INTERNAL code
- Test breaks when refactoring without behavior change
- Test name describes HOW not WHAT
- Verifying by bypassing the interface

Note the scope: asserting calls on a mocked TRUE EXTERNAL boundary (the
payment provider SDK, the email API) is legitimate and often the only
verification possible - "charges the gateway exactly once" IS the behavior
when the gateway is external. The anti-pattern is spying on your own
internals. mocking.md has the decision rule.

```typescript
// BAD: Bypasses interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

One nuance: when the interface CANNOT reveal the effect (e.g. a DB
constraint or trigger with no read path yet), verifying through the DB is
acceptable, but first ask whether the missing read path is itself the gap.
