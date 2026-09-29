---
name: tdd
description: "API and database skill sets: load before the first backend or schema edit of a session, and for any testable web logic. Owns failing-test, implementation and refactor cycles for behavior changes and bug fixes."
---

# Test-driven behavior changes

## Choose the test boundary

Inspect existing tests and scripts. Test through the public interface that exposes
the behavior, using the smallest meaningful unit or integration boundary. Load
[tests.md](tests.md) for examples, [mocking.md](mocking.md) when external boundaries
need doubles, and [harness.md](harness.md) only for test infrastructure work.

Derive cases from the requested behavior. Prioritize money/rounding, authorization
and denied paths, tenant isolation, legal state transitions, validation, concurrent
writes, and retry/idempotency. Include these when the change touches their logic.
Do not add unrelated behaviors or demand a new test suite for static prose/styles.

## Work in short cycles

1. Write one meaningful failing test and run it. Confirm the failure is the missing
   behavior, not a setup/import error. If it already passes, establish whether the
   behavior exists or the test misses the defect.
2. Implement the smallest complete behavior that passes. Do not build all layers
   separately or write a large suite against imagined APIs before checking one path.
3. Add the next failure/edge case. Keep assertions independent of private helpers,
   exact markup, or incidental implementation details.
4. Refactor once green, preserving the public behavior. Run the affected checks.

For bugs, retain a regression test that fails for the original symptom. If an
executable reproduction is impractical (for example a device-only rendering defect),
record the limitation and the concrete manual reproduction; do not claim automated
coverage or create a test that merely matches the fix's source text.

In a build of many areas (a milestone with dozens of operations or screens), wire
and test one area at a time: register its routes or screen alone, see its first
test fail, then build it. A route file or barrel that imports use cases not yet
written is the moment test-first gives way to batch implementation; split it so
each area compiles on its own. Every commit that adds a use case or screen carries,
or follows, a test that failed without it; say which when reporting.

A change to a test is itself a change: run the edited test file and observe its
result before committing, whatever the commit hook runs.

When the app's build applies a transform (the React Compiler, a Babel or SWC
plugin), component tests run through the same transform, or they cannot see the
defects it introduces.

Test files follow existing repository naming and tools. New harnesses should cover
one real behavior before expanding. Use isolated test databases and deterministic
fixtures; never aim mutation tests at production. Verify transaction/race behavior
with the actual database where mocks would hide it.

## Completion evidence

Report the relevant failing/passing cycle, final targeted check results, and any
untested consequential case. Targeted runs select by what changed, not by what was
being built: when a change touches a shared component, module or primitive, its own
test files and guard tests are in the run, and an intended behavior change updates
the old assertion in the same commit. Run broader checks when required by the repo or when
the change crosses shared boundaries. Passing unit tests alone do not establish
contract compatibility, browser behavior, or release readiness.
