---
name: improve-animations
description: "Audit motion across a specified UI area and produce prioritized findings and implementation steps. Read-only unless implementation is separately requested; a single requested animation belongs to animate."
---

# Audit motion across a surface

Stay within the requested UI area. Read existing motion tokens and primitives,
then inspect entrances/exits, frequently repeated actions, gesture cancellation,
reduced motion, keyboard/touch feedback, and perceived latency. The audit is
read-only unless the user also requests fixes.

Use [AUDIT.md](AUDIT.md) as a checklist for relevant behaviors, not a mandatory
list of findings. Prioritize concrete user harm, accessibility defects, and broken
state transitions before taste or speculative performance improvements.

For each supported finding, give location, observed code behavior, likely impact,
and a scoped correction. If requested, use [PLAN-TEMPLATE.md](PLAN-TEMPLATE.md) to
prepare implementation steps, adapting the format to the task. Reuse existing
tokens; numeric values are starting points until rendered review supports them.

No browser/dev server is launched unless requested. Separate static findings from
feel or device-performance questions. A useful audit can have no findings; do not
manufacture work to meet a count or claim a measured frame rate without evidence.
