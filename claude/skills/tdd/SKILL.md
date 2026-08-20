---
name: tdd
description: >-
  Test-driven development: the DEFAULT methodology for all feature and
  bug-fix work, not an opt-in. Apply AUTOMATICALLY and ALWAYS when
  implementing a feature, endpoint, service, component with logic, or fixing
  a bug, and whenever writing or modifying tests (unit or integration),
  setting up a test runner/harness, or asked for "red-green-refactor" or
  test-first work. Behaviors become failing tests before logic is written.
---

# Test-Driven Development

## Philosophy

**Core principle**: Tests verify behavior through public interfaces, not
implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through
public APIs. They describe _what_ the system does, not _how_. A good test
reads like a specification: "user can checkout with valid cart". These tests
survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation: they mock internal
collaborators, test private methods, or verify by bypassing the interface.
Warning sign: a refactor with unchanged behavior breaks the test.

See [tests.md](tests.md) for examples, [mocking.md](mocking.md) for mocking
rules, and [harness.md](harness.md) for the house test stack and setup
(read harness.md FIRST when the repo has no test infrastructure yet).

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** Bulk-written
tests test _imagined_ behavior and the _shape_ of things; they pass when
behavior breaks and fail when it's fine.

```
WRONG (horizontal):            RIGHT (vertical, tracer bullets):
  RED:   test1..test5            RED->GREEN: test1 -> impl1
  GREEN: impl1..impl5            RED->GREEN: test2 -> impl2  (informed by 1)
```

One test, minimal code to pass it, repeat. Each cycle responds to what the
previous one taught you.

## Workflow

### 1. Plan the behaviors

Derive the behavior list from the spec or PLAN.md (see `app-blueprint`).
List behaviors, not implementation steps, and prioritize: you can't test
everything, so order by risk.

**Always-test floor (non-negotiable even under time pressure):** money math
and rounding, auth and permission checks (including the denied paths),
tenant isolation (org B cannot touch org A), domain invariants and
state-machine transitions (including illegal ones), idempotency (webhooks,
retries), and validation rejections. Happy-path-only
test suites are not acceptable for production work.

**Working from an approved spec or in an autonomous build:** do NOT pause
for per-feature test-plan approval; record the chosen behaviors in PLAN.md
and proceed. **Working interactively on vague requirements:** confirm the
public interface and top behaviors with the user before starting.

### 2. Tracer bullet

Write ONE test for the first behavior, watch it fail (RED), write minimal
code to pass (GREEN). This proves the whole path (harness, imports, DB,
app wiring) works end to end before investing further.

A test must fail for the RIGHT reason first: run it, read the failure. A
test that passes immediately is testing nothing (or the behavior already
exists - find out which).

### 3. Incremental loop

For each remaining behavior: RED -> GREEN.
- One test at a time; only enough code to pass it.
- Don't anticipate future tests; don't add speculative features.
- Keep tests on observable behavior via the public interface.

### 4. Refactor (only while GREEN)

After tests pass, improve the design: extract duplication, deepen modules,
tighten types. Candidates and procedures in [refactoring.md](refactoring.md).
Run the tests after every refactor step. **Never refactor while RED.**

## Bug fixes: regression-test-first

1. Reproduce the bug as a failing test at the public interface, named after
   the behavior ("expired token is rejected on refresh"), not the ticket.
2. Confirm it fails for the reported reason.
3. Fix with minimal code; the test goes green.
4. Keep the test forever. Check siblings: the same bug class often exists in
   adjacent code paths; add tests there too if found.

Never fix a bug without a test that would have caught it: an untested fix
regresses silently.

## Checklist per cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses the public interface only
[ ] Test failed first, for the right reason
[ ] Test would survive an internal refactor
[ ] Code is minimal for this test; no speculative additions
[ ] Always-test floor covered for this feature (money/auth/invariants/idempotency)
```
