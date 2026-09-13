---
name: emil-design-eng
description: "Polish an existing web interaction or component that works but feels awkward: feedback, interruption, focus, hover, and perceived responsiveness. For building a specific animation use animate; for responsive layout use mobile-first-ui."
---

# Existing interaction polish

Identify the specific friction: unclear feedback, delayed response, lost focus,
interrupted transitions, awkward hover, or confusing spatial behavior. Preserve
working product behavior and the existing visual system. Fix the interaction with
the smallest change; do not add animation simply because this skill is loaded.

- Immediate feedback must not wait for a network request or decorative animation.
- Preserve focus, keyboard access, and touch equivalents when changing interaction.
- Interrupted actions should converge to the latest state without jumps or lockout.
- Loading and failure states should keep the next action understandable.
- Prefer existing component capabilities and motion tokens over new abstractions.

For popover origin, tooltip groups, pointer capture, or similar mechanics, read the
matching section in [REFERENCE.md](REFERENCE.md). For a requested animation use
animate's decision process; for Sonner APIs use ask-sonner only if relevant. An
Apple-style material or gesture is not a default requirement for every product.

## Completion

State the interaction defect addressed and the relevant functional/static checks.
Identify feel or device behavior that still needs the user's rendered review.
A review reports concrete location, impact, and suggested correction; no fixed
findings table or minimum number of issues is required.
