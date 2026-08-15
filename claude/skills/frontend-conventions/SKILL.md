---
name: frontend-conventions
description: >-
  Structural conventions for the user's Next.js 16 (App Router) + React 19 +
  TypeScript frontends (e.g. dms-frontend, website-frontend) using RTK Query,
  react-hook-form + Zod, and shadcn/ui. Apply AUTOMATICALLY and ALWAYS when
  creating or modifying frontend code in these stacks — pages, components, RTK
  Query API slices, hooks, forms/validation, redux store, types, or data
  fetching — and when refactoring or reviewing your own frontend output. Use
  whenever the task touches a React component, a route, the data layer, or a form.
---

# Frontend Conventions

How these apps are built. Codify the **improved** patterns below; do not copy
legacy shortcuts (stray `console.*`, needless `"use client"`).

## Scope boundary — do NOT duplicate other skills
This skill is **architecture and structure only**. Defer:
- **Creative/visual direction** (look, typography, layout taste) → `frontend-design`.
- **Accessibility, performance, UX quality gate** (ARIA, focus, touch targets,
  reduced-motion, semantic HTML, Core Web Vitals) → Vercel Web Interface Guidelines.
- **Tests** → the testing skill.
- **UI verification**: the user reviews the rendered UI themselves and requests
  adjustments — do not run dev servers or take screenshots to self-verify.

Build *for* a11y and performance here (Server Components by default, typed data,
predictable states), but let those skills own their domains.

---

## The two rules everything hangs on

1. **Server Components by default.** A file is a Server Component unless it needs
   interactivity. Add `"use client"` only when the component uses hooks, state,
   effects, event handlers, RTK Query, or browser APIs. Push client logic to small
   leaf "islands"; keep pages/layouts and static display on the server.
   *Why:* less JS shipped, better LCP/SEO — critical for `website-frontend` public pages.

2. **All client data goes through RTK Query.** Never `fetch` in a component or
   `useEffect`. Define endpoints on the central `apiSlice` via `injectEndpoints`,
   consume via generated hooks.
   *Why:* one cache, automatic refetch/invalidation, dedup, and the shared auth-refresh path.

---

## Self-audit checklist — run against every frontend change

```
RENDERING
[ ] Server Component unless it needs interactivity; "use client" only on leaf islands
[ ] No data fetching in client components via fetch/useEffect — use RTK Query
[ ] Public/SEO pages render on the server (metadata, no client-only data gates)

DATA LAYER
[ ] New endpoints added via apiSlice.injectEndpoints (not a new createApi)
[ ] Queries declare providesTags; mutations declare invalidatesTags
[ ] Request/response typed with I*Response / I*QueryParams from types/
[ ] Query params built with a typed helper, not string concatenation

STATE & FORMS
[ ] Forms use react-hook-form + zodResolver; schema lives in validations/
[ ] Frontend Zod schema mirrors the backend contract for that endpoint
[ ] Server cache state (RTK Query) not duplicated into local/Redux state

UX STATES
[ ] Every query consumer handles isLoading / isError / empty (skeleton/error/empty)
[ ] Mutations surface success + error via the shared toast/error-message helper

HYGIENE & TYPES
[ ] No console.* in shipped code (use a dev-only logger if needed)
[ ] No `any`; response shapes typed in types/, never inline
[ ] Imports use the @/ alias; class names composed with cn()
[ ] Files kebab-case; one component concern per file
```

---

## Conventions (each with its *why*)

### Folder & naming
- Under `src/`: `app/ components/ hooks/ lib/ redux/ types/ validations/ utils/ static-data/`.
- Components grouped by feature: `components/<feature>/` with sub-folders
  (`data-table/`, `detail/`, `profile/`) and a shared `components/ui/` (shadcn).
- **Use `validations/`** (plural) for the Zod schema directory — matches the backend.
- Files kebab-case; one component per file; `@/` path alias everywhere.
*Why:* predictable locations; mirrors the backend so the mental model is one.

### Data layer (RTK Query) — see `reference/data-layer.md`
- One `redux/api-slice.ts` owns `createApi`, `fetchBaseQuery` (`credentials:"include"`),
  the Mutex-guarded **silent token refresh**, and `tagTypes`.
- Feature files (`redux/<feature>-api.ts`) call `apiSlice.injectEndpoints`.
- Queries `providesTags`; mutations `invalidatesTags` so lists stay fresh.
- Build query strings with a typed helper (`buildDateRangeUrl`-style), never ad hoc.
*Why:* one cache + one auth path; cache correctness is declarative, not manual.

### Components & rendering — see `reference/components-forms.md`
- Server Component by default; `"use client"` only on interactive leaves.
- Fetch data in Server Components (or via RTK Query in client islands); pass plain
  props down. Don't lift a whole page to the client for one interactive widget.
*Why:* smaller bundles, faster first paint, SEO on public pages.

### Forms & validation
- react-hook-form + `@hookform/resolvers/zod`; schema in `validations/`.
- The **frontend Zod schema mirrors the backend** validation for that endpoint
  (document the mirror in a comment) so client and server agree.
*Why:* instant client feedback with the same rules the server enforces.

### UX states (loading / error / empty)
- Every `useXQuery` consumer handles `isLoading` (skeleton — reuse `*Skeleton`
  components), `isError` (error UI), and **empty** (no-rows state) explicitly.
- Mutations route errors through a **shared RTK-Query-error → message** helper and
  show a toast; never swallow.
*Why:* no blank/janky screens; consistent failure UX.

### Types
- Request/response interfaces (`I*Response`, `I*QueryParams`) live in `types/` and
  are shared by the api slice and components. Never inline a response shape.
*Why:* one source of truth; refactors are type-checked end to end.

### Env
- Read `NEXT_PUBLIC_*` through a small typed env module (mirror the backend `ENV`)
  that validates presence at module load, so a missing public var fails at build,
  not at runtime in the browser.
*Why:* misconfiguration is caught before users hit it.

### Hygiene
- **No `console.*` in shipped code.** Remove debug logging or route it through a
  dev-only logger. Keep doc comments truthful.
*Why:* console noise leaks internals and clutters production.

---

## When unsure
If something looks like a deliberate choice vs. a smell (e.g. a client page that
could be a Server Component), ask rather than guess. Read the relevant reference
file before writing the data layer or a form.
