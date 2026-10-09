---
name: lfms-api-before-web
description: LFMS - finish a module's whole API (every sub-phase) before starting any of its web screens (owner, 5 Oct 2026)
metadata:
  type: feedback
---

Build the API of a module completely (all its sub-phases, e.g. payments P11.1-P11.4 incl. every provider) before any web work for it; never stop midway through the API to build UI.

**Why:** owner, 5 Oct 2026: "isn't it normally api first, why are you stopping midway to handle the web ui" (after I started P11.1 web with P11.2-P11.4 API unbuilt).

**How to apply:** at a sub-phase boundary, continue with the next API sub-phase; web starts only once the module's API is done. Related: [[lfms-main-features-build-mode]].
