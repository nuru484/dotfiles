---
name: mobile-keyboard-safe-overlays
description: "Any bottom sheet, drawer or modal with inputs must stay clear of the phone's on-screen keyboard; the user asked for this system-wide and for future sessions"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b90ced91-69c6-48da-8759-629929cc8bf5
  modified: 2026-09-05T14:39:32.414Z
---

On the user's web apps (LFMS first, but the rule is general), a form drawn in a bottom sheet, side drawer or modal must never let the mobile keyboard cover the input being typed in. The user asked for this "across the whole system" on 2026-09-05 and wanted it remembered so later sessions and other models do not repeat the mistake.

**Why:** a phone keyboard takes 40 to 50 percent of the screen. A fixed-position overlay anchored to the bottom of the layout viewport stays behind the keyboard on iOS Safari (which does not shrink the layout viewport) and, without the viewport meta, on Chrome Android too. The user tests on a phone and sees the input disappear.

**How to apply (the LFMS implementation, reuse the shape elsewhere):**
- Viewport meta gets `interactive-widget=resizes-content` (Next: `export const viewport: Viewport = { interactiveWidget: "resizes-content" }`) so browsers that honour it shrink the layout viewport and `dvh` and `bottom: 0` follow the keyboard.
- A hook reads `window.visualViewport` (height and offsetTop against `window.innerHeight`), ignores shifts under about 120px (address bar), and the overlay primitive applies the remainder as `bottom` and a `max-height: calc(100dvh - inset)` inline style. In LFMS: `src/hooks/use-keyboard-inset.ts`, used by `SheetContent` and `DialogContent`.
- On focus of an input, textarea or select inside the overlay, wait ~250ms for the keyboard animation, then `scrollIntoView({ block: "center" })` on the focused element (`revealOnFocus`).
- Do it once at the overlay primitive, never per form, and never build an overlay outside those primitives. Overlays scroll internally with the footer kept reachable.
- Test: a unit test on the pure inset function plus a component test that stubs `visualViewport`, raises it, asserts the inline `bottom`/`maxHeight`, and asserts `scrollIntoView` after the delay with fake timers.

Related: [[design-for-worst-case-content]], [[khadys-dev-testing-notes]].
