# Refactor Candidates

Run this pass only while GREEN, re-running tests after each step.

- **Duplication** -> extract a function/module after the SECOND repetition
  (not the first: two instances reveal the right abstraction, one is a guess).
- **Long functions** -> extract private helpers once a function handles more
  than one concern or needs scroll to read; keep tests on the public
  interface, never on the extracted helpers.
- **Shallow modules** (interface as complex as the implementation, e.g. a
  service function that just forwards to Prisma) -> inline them, or deepen:
  move the surrounding logic (validation, invariants, mapping) inside so the
  caller's life gets simpler.
- **Feature envy** (function mostly reads another module's data) -> move the
  logic to where the data lives.
- **Primitive obsession** (same 2-3 primitives always travel together, or a
  string with rules, like money-as-number + currency-as-string) -> introduce
  a type/object (`Money`, `DateRange`) with the rules attached.
- **Boolean flag parameters** that switch behavior -> split into two named
  functions.
- **Knowledge the new code reveals about old code** -> if this cycle exposed
  a bad existing pattern, fix it everywhere NOW or record it in PLAN.md;
  never leave two styles coexisting silently (see app-blueprint's
  consistency protocol).

Discipline: refactoring never changes behavior, so it never requires new
tests and never breaks existing ones. If a test breaks, the step changed
behavior - revert and re-think. Commit before large refactors so each is
independently revertible.
