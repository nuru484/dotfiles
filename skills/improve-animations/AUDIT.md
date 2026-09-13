# Motion review rubric

Review only behaviors changed by the task. Existing design tokens and explicit user
choices take precedence over stylistic defaults.

| Concern | Evidence to inspect |
| --- | --- |
| Purpose and frequency | Motion clarifies feedback/state without slowing routine work |
| Interruption | Repeated input converges to the latest state without jumps or lockout |
| Origin and focus | Anchored overlays retain spatial relation and correct focus behavior |
| Accessibility | Reduced motion, keyboard/touch equivalence, pointer cancellation |
| Performance | Layout/paint costs and busy-thread behavior; measure before claiming jank |
| Cohesion | Existing timing and component behavior remain consistent |

Prefer targeted transitions to transition: all. Transform/opacity are useful
starting points, not guarantees of hardware acceleration. Height animation can be
justified for layout transitions; a fade can be sufficient. Keyboard-triggered
motion is not automatically a defect. Zero animation is a valid reduced-motion mode.

With no existing tokens, small feedback often starts at 100-160ms and overlays at
125-300ms. Longer travel may need more time. Choose an easing that provides prompt
feedback and matches the action. Exact timing is a tuning decision, not a proof of
correctness. Do not block work because a curve is not in a catalog.

Report location, impact, evidence, and correction for supported findings. Device
smoothness and subjective feel require rendered observation. Preserve the user's
visual-review workflow and disclose what remains unverified.
