---
name: systematic-debugging
description: "Diagnose a reproducible bug, failing check, or unexpected runtime behavior before changing code. Use evidence and a bounded hypothesis loop; do not expand an isolated failure into an unrelated architecture audit."
---

# Diagnose before changing behavior

Read the complete relevant error, locate the failing path, and reproduce the
symptom with the smallest safe input. Compare recent changes, environment, and a
working neighboring implementation. Use existing request/error identifiers and
logs before adding instrumentation.

Form one hypothesis supported by the evidence. Make a minimal experiment that
separates it from alternatives; inspect the result before changing another variable.
Keep experiments isolated and remove diagnostic changes that are not needed.
Never dump environment variables, tokens, request bodies, or personal data to logs;
check presence and sanitized structure instead of values.

When a hypothesis is confirmed, add a regression test at the affected behavior
boundary and fix the cause. Follow tdd for the failing/passing cycle. Inspect
related paths when evidence suggests they share the defect, without expanding
into an unrelated rewrite.

If repeated attempts do not narrow the cause, stop repeating them. Revisit the
reproduction and assumptions, gather a discriminating observation, and explain the
remaining uncertainty. Three failures do not by themselves prove bad architecture.
Ask for input when a missing reproduction, external access, or product decision
prevents progress; continue any independent work.

For external or intermittent faults, distinguish a mitigation from a confirmed
root-cause fix. Bounded retries require idempotent operations and a termination
condition; do not retry an uncertain payment or mutation blindly.

## Supporting techniques

- [root-cause-tracing.md](root-cause-tracing.md): trace an invalid value backward.
- [condition-based-waiting.md](condition-based-waiting.md): replace arbitrary sleeps
  with bounded condition checks.
- [defense-in-depth.md](defense-in-depth.md): choose additional validation where
  independent trust boundaries need it, not at every internal call.

Finish with the observed cause or remaining uncertainty, the change made, and
reproduction/check results. An unobserved production outcome remains unverified.
