---
name: find-animation-opportunities
description: "Inspect a specified UI area and propose worthwhile motion opportunities without changing code. Use when asked where animation could help; fixing existing motion belongs to animate or improve-animations."
---

# Find useful motion opportunities

Inspect the requested files or UI area and its existing motion conventions. Stay
read-only unless implementation is authorized. Identify places where motion could
clarify feedback, state, or spatial continuity; do not propose motion merely because
an element is static. High-frequency actions deserve restraint.

For each worthwhile opportunity, describe the current behavior, expected user
benefit, affected location, and a concrete starting implementation using existing
tokens. Include reduced-motion and keyboard/touch considerations. A short fade or
no animation can be the correct recommendation. Avoid imposing stagger, custom
curves, or expensive effects on every component.

Rank by user value and implementation cost. Omit speculative or redundant options;
there is no minimum finding count. Explain what requires rendered review and do not
claim device performance from static inspection. Specific implementation belongs
to animate; auditing existing motion across a surface belongs to improve-animations.
