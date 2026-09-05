---
name: no-shadows-unless-explicit
description: UI styling preference — do not add box-shadows to components unless explicitly asked
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019dc29a-b928-4737-bc69-fd5f7133277e
---

Do not add shadows (Tailwind `shadow-sm`, `hover:shadow-md`, `transition-shadow`, etc.) to UI components — on cards, buttons, selected/active states, anything — unless the user explicitly asks for a shadow.

**Why:** The user prefers a flat, shadow-free aesthetic and called this out after I carried `shadow-sm`/`hover:shadow-md` over from existing patterns into new madrasa + donate components.

**How to apply:** When cloning or matching existing components, strip shadow utility classes from what you add. `shadow-none` (which removes a default shadow) is fine. Applies to the mhp website-frontend and dms-frontend.
