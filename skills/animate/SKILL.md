---
name: animate
description: "Implement or adjust a specific web animation or transition, including interruption and reduced motion. Use for requested motion changes; motion audits belong to improve-animations and native animation to animate-expo."
---

# Implement a specific web animation

Inspect the target interaction, existing tokens, component primitive, and installed
animation library. Preserve product behavior and explicit design choices. Choose
motion that provides feedback or clarifies a transition; high-frequency actions
usually need less motion, not an arbitrary ban on keyboard-triggered feedback.

## Decisions

- Prefer the existing primitive's animation API. Simple state changes usually need
  CSS transitions; springs/gestures/layout/exit choreography may justify Motion or
  an existing library. Do not install a library for a simple fade.
- Prefer transform and opacity where they fit. Compositor acceleration depends on
  the browser, property, and animation implementation; it is not guaranteed by CSS
  alone. Layout properties may be necessary for an accordion; measure the tradeoff.
- Reuse existing duration/easing tokens. With no tokens, start around 100-160ms for
  press feedback, 125-250ms for small overlays, and 200-300ms for larger transitions.
  Longer travel may justify longer duration. These are tuning ranges, not tests.
- Favor prompt response and a decelerating entrance; choose other curves when the
  existing design or physical action calls for them. Preserve anchored transform
  origin for popovers; centered modals can remain centered.
- Rapid actions must retarget from the current presentation without flicker, stale
  state, or disabled input. Gestures need pointer capture/cancellation and velocity
  handling when relevant. Do not make destructive behavior depend on animation end.
- Honor prefers-reduced-motion. Zero animation or a short fade are both valid;
  remove nonessential movement. Gate hover-only motion to hover-capable pointers
  and preserve equivalent keyboard/touch feedback.

For a matching component, read only its section in [RECIPES.md](RECIPES.md).
Adapt the recipe to installed APIs, existing tokens, semantics, and reduced-motion
requirements. Reuse an available accessible primitive; do not implicitly invoke
explicit-only pick-ui-library or review-animations skills.

## Completion

Check state interruption, dismissal/focus, reduced motion, and relevant component
behavior with the project's available functional checks. Static inspection cannot
prove smoothness or feel. Report the chosen behavior and what the user should
inspect in the rendered result. Do not start a browser/dev server unless requested.

Performance reference: [Motion animation performance](https://motion.dev/docs/performance).
