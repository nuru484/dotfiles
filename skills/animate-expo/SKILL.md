---
name: animate-expo
description: "Implement or fix React Native/Expo animations, gestures, and animated navigation using APIs compatible with the installed SDK. Use for native motion work, not web animations or general application scaffolding."
---

# Implement native motion

Inspect the installed Expo SDK, React Native, Reanimated, and navigation versions.
Use their documented APIs and existing project choices; do not upgrade the SDK or
replace navigation solely to match a recipe. Install needed packages through the
project's Expo-compatible workflow. Core Animated is suitable for supported simple
cases; continuous gestures may benefit from Reanimated/UI-thread worklets.

Choose motion for a specific feedback, state, or spatial purpose. Keep frequent
interactions quick and interruptible. Preserve platform navigation conventions,
reduce motion when requested by the OS, and avoid extra animation on native
behaviors already providing feedback.

Read matching sections of [REFERENCE.md](REFERENCE.md) for platform decisions or
[RECIPES.md](RECIPES.md) for component implementations. Platform/experimental APIs
require a version check. Do not add keyboard controllers, haptics, Lottie, or Skia
without a concrete need. Transform/opacity are often cheaper than layout work,
but no property is free and performance depends on the rendered scene.

## Completion

Check gesture cancellation, interruption, accessibility, and the affected state
transitions. Report checks actually run. Device feel/performance requires a release
build on a representative device; keep it explicitly unverified when unavailable.
The user's rendered-review preference applies unless they request device/browser
verification. Do not invent a measured frame rate from code inspection.
