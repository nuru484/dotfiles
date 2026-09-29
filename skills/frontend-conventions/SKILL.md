---
name: frontend-conventions
description: "Web skill set: load with the rest of the set before the first frontend edit of a session (any Next.js page, component, form, RTK Query slice or style). Owns App Router structure, RTK Query data flow, forms and rendering boundaries in the house stack."
---

# Frontend architecture and data flow

Applies to the house Next.js App Router + RTK Query stack. Inspect the nearest
working component, route, API slice, and form before introducing a new pattern.
Existing project decisions take precedence; do not migrate another React stack.

## Core decisions

- Keep server-only data and code outside the client import graph. Use small client
  boundaries for hooks, handlers, browser APIs, and RTK Query. Server Components
  may import/render Client Components and pass server-rendered children to them.
- In this stack, client API data uses the existing RTK Query apiSlice and injected
  endpoints. Do not add a second cache or copy server data into local state.
  Server Components call the existing API with narrowly scoped auth forwarding.
- Mutations use the Express API rather than introducing Server Actions or direct
  frontend database access. Preserve project exceptions explicitly.
- Forms use the existing react-hook-form/Zod conventions. Keep form state separate
  from reusable UI coordination state. Preserve API nullability and error contracts.
- Reuse project primitives and tokens. Add a library only for an unmet requirement,
  after checking current compatibility; a simple list does not need a table engine.

## Read only the relevant detail

- File organization and house library choices: [reference/conventions.md](reference/conventions.md).
- Query/cache/auth refresh: [reference/data-layer.md](reference/data-layer.md).
- Rendering and basic forms: [reference/components-forms.md](reference/components-forms.md).
- Server-paginated tables: [reference/data-tables.md](reference/data-tables.md).
- Dashboard data/widgets: [reference/dashboards.md](reference/dashboards.md).
- Dependent/repeating forms: [reference/complex-forms.md](reference/complex-forms.md).
- Changed accessibility or public metadata: [reference/a11y-seo.md](reference/a11y-seo.md).

Use mobile-first-ui when layout changes, design-taste for visual direction, and
animate for motion. None is a mandatory full audit for a data-only edit.
Use project-scaffold only for infrastructure actually needed and missing.

## Completion

Verify the affected query/mutation/form behavior, cache invalidation, and relevant
loading/error/empty or submission states. Check labels, focus, and keyboard access
when interactive semantics change. Run relevant project checks; distinguish code
inspection from the live walk (mobile-first-ui, Verification). When a change adds
or edits route files (`page.tsx`, `layout.tsx`, `route.ts`), run the production
build too: a page module exporting anything beyond its allowed fields passes tsc,
lint and tests and fails only `next build`; keep helpers in a feature module.
When the app enables the React Compiler, component tests run through it, and
nullable props are never read with `x!.prop` inside hooks or closures.
Report contract dependencies if
the API side cannot be inspected or updated in this task.
