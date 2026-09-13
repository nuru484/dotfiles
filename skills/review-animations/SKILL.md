---
name: review-animations
description: "Review specified animation code for concrete usability, accessibility, interruption, and performance issues. Report supported findings rather than enforcing arbitrary numeric preferences."

disable-model-invocation: true
---

# Review the specified motion

Review the supplied diff or component for concrete problems. Do not invent findings
because a curve differs from a preference. General code-review requests should be
answered at their requested scope rather than refused because this skill is narrow.

Check purpose and frequency, response latency, interruption/reversal, trigger origin,
reduced-motion behavior, keyboard/touch equivalence, and unbounded property changes.
Prefer transform/opacity where suitable; layout animation is not automatically a
bug when needed and measured. A fade or zero motion is a valid accessible design.

Read [STANDARDS.md](STANDARDS.md) for matching examples only. Its numeric values and
style preferences are heuristics, not automatic blockers. Prioritize demonstrated
accessibility and correctness problems over speculative performance or taste issues.

Report each supported finding with location, user impact, and a concrete correction.
Separate code evidence from feel/performance requiring rendered inspection. If no
supported finding exists, say so without claiming runtime verification. Follow the
user's visual-review workflow; do not start a browser or dev server by default.
