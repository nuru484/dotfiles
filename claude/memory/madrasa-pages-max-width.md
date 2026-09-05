---
name: madrasa-pages-max-width
description: Madrasa dashboard tables/views must use the standard container max-width like the donor pages
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 019dc29a-b928-4737-bc69-fd5f7133277e
---

In **dms-frontend**, the madrasa dashboard pages (tables) and detail views must
use the same constrained width as the donor pages — never full-width.

- Dashboard / table pages (e.g. `app/dashboard/madrasa/page.tsx`): wrap in
  `<div className="container mx-auto space-y-6">`.
- Detail views (e.g. `app/dashboard/madrasa/[id]/detail/page.tsx`): wrap in
  `container mx-auto space-y-6` with an inner `mx-auto max-w-7xl space-y-6`,
  matching `app/dashboard/donors/[id]/detail/page.tsx`.

**Why:** the dashboard `<main>` has no max-width, so a bare `space-y-6` wrapper
lets madrasa content stretch wider than every other page. The user flagged this
twice (the donors data table and the donor detail page).

**How to apply:** any new madrasa tab, table, or view inherits the page
wrapper's `container mx-auto` — keep new components inside it; don't reintroduce
full-width wrappers.
