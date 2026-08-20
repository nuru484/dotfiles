---
name: frontend-conventions
description: >-
  Structural conventions for the user's Next.js 16 (App Router) + React 19 +
  TypeScript frontends (e.g. dms-frontend, website-frontend) using RTK Query,
  react-hook-form + Zod, and shadcn/ui. Apply AUTOMATICALLY and ALWAYS when
  creating or modifying frontend code in these stacks - pages, components, RTK
  Query API slices, hooks, forms/validation, redux store, types, or data
  fetching - and when refactoring or reviewing your own frontend output. Use
  whenever the task touches a React component, a route, the data layer, or a form.
---

# Frontend Conventions

How these apps are built. Codify the **improved** patterns below; do not copy
legacy shortcuts (stray `console.*`, needless `"use client"`).

## Scope boundary - do NOT duplicate other skills
This skill is **architecture and structure only**. Defer:
- **Creative/visual direction** (look, typography, layout taste) → the
  `frontend-design` plugin skill, constrained by `design-taste`'s
  anti-default bans (palettes, fonts, layout tells - always on).
- **Marketing/landing/public-page composition** → `design-taste`.
- **Interaction feel & motion** (animations, easing, press/hover states,
  transitions) → `emil-design-eng`; building a specific animation → `animate`.
- **Responsive structure & content hardening** → `mobile-first-ui` (always on).
- **A11y/perf audit** → `web-design-guidelines`; run its self-check after
  completing UI work, not only when asked.
- **Tests** (component tests, MSW, the harness) → `tdd`.
- **Canonical infra code** (store, StoreProvider, api-slice, auth-slice,
  PUBLIC_ENV, extractApiErrorMessage, shared state components) →
  `project-scaffold`. If a named module doesn't exist yet, copy it from there.
- **UI verification**: the user reviews the rendered UI themselves and requests
  adjustments - do not run dev servers or take screenshots to self-verify.

**Write-time a11y + SEO floor (non-deferrable):** semantic elements over div
soup, every input labelled, keyboard reachability and visible focus, alt
text, WCAG AA contrast (4.5:1 body / 3:1 large + UI) in both themes, touch
targets ≥ 44px, respect `prefers-reduced-motion`; public pages get metadata
+ canonical + sitemap entry, authed pages get noindex. Full recipes:
`reference/a11y-seo.md` - read it before building any page or form. The
audit skill catches what slips; it does not excuse skipping these while writing.

**Precedence over the vercel-* skills:** when `vercel-react-best-practices`
or `vercel-composition-patterns` suggest a different stack choice (SWR,
Server Actions, direct DB access from Next), THIS skill wins: apply their
underlying principle through RTK Query and the Express API instead.

## Blessed libraries (decided picks - do not re-litigate)

`pick-ui-library` is invocation-only, so unattended builds never see its
decisions; the picks that matter to this stack are restated here. Use them
without churning; deeper rationale and the full curated list live in
`pick-ui-library`.

| Need | Use | One-line convention |
| --- | --- | --- |
| Data tables | **TanStack Table** | Headless, manual mode, wired to RTK Query + URL params per `reference/data-tables.md` |
| Charts | **recharts** | Dashboards; conventions in `reference/dashboards.md` |
| Virtualization | **Virtuoso** | Client-rendered lists longer than ~100 rows |
| Drag & drop | **dnd kit** | Sortable lists, kanban, reorderable rows |
| Command menu | **cmdk** | The ⌘K palette (shadcn `Command` wraps it) |
| Theme switching | **next-themes** | Wire into the scaffold root layout when the app has a theme toggle |
| OTP input | **input-otp** | Verification-code fields (shadcn `InputOTP` wraps it) |
| Toasts | **sonner** | Already canonical; the scaffold layout mounts `<Toaster />` |

---

## The three rules everything hangs on

1. **Server Components by default.** A file is a Server Component unless it needs
   interactivity. Add `"use client"` only when the component uses hooks, state,
   effects, event handlers, RTK Query, or browser APIs. Push client logic to small
   leaf "islands"; keep pages/layouts and static display on the server.
   *Why:* less JS shipped, better LCP/SEO - critical for `website-frontend` public pages.

2. **All CLIENT-side data goes through RTK Query.** Never `fetch` in a client
   component or `useEffect`. Define endpoints on the central `apiSlice` via
   `injectEndpoints`, consume via generated hooks. (Server Components fetch
   directly from the API with cookie forwarding - that is the server half,
   see `reference/components-forms.md`.)
   *Why:* one cache, automatic refetch/invalidation, dedup, and the shared auth-refresh path.

3. **No Server Actions, no DB access in the frontend.** Every mutation goes
   through RTK Query to the Express `/api/v1` contract. Ignore any guidance
   (including vercel-* rules) that models mutations as `'use server'` actions
   or queries the database from Next.
   *Why:* one mutation path keeps the error contract, validation mirror, auth,
   and audit trail in one place; two paradigms fork the codebase.

---

## Self-audit checklist - run against every frontend change

```
RENDERING
[ ] Server Component unless it needs interactivity; "use client" only on leaf islands
[ ] No data fetching in client components via fetch/useEffect - use RTK Query
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

A11Y & SEO (reference/a11y-seo.md)
[ ] Landmarks + single h1; interactivity on real <button>/<a>; icon buttons labelled
[ ] Form errors tied via aria-describedby; contrast AA in both themes
[ ] Public page: metadata + canonical + sitemap; authed page: noindex

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
- **No barrel `index.ts` files in the frontend** (they defeat tree-shaking and
  slow builds); import directly from source files. Barrels are a backend-only
  convention.
- **Use `validations/`** (plural) for the Zod schema directory - matches the backend.
- Files kebab-case; one component per file; `@/` path alias everywhere.
*Why:* predictable locations; mirrors the backend so the mental model is one.

### Data layer (RTK Query) - see `reference/data-layer.md`
- One `redux/api-slice.ts` owns `createApi`, `fetchBaseQuery` (`credentials:"include"`),
  the Mutex-guarded **silent token refresh**, and `tagTypes`.
- Feature files (`redux/<feature>-api.ts`) call `apiSlice.injectEndpoints`.
- Queries `providesTags`; mutations `invalidatesTags` so lists stay fresh.
- Build query strings with a typed helper (`buildDateRangeUrl`-style), never ad hoc.
*Why:* one cache + one auth path; cache correctness is declarative, not manual.

### Components & rendering - see `reference/components-forms.md`
- Server Component by default; `"use client"` only on interactive leaves.
- Fetch data in Server Components (or via RTK Query in client islands); pass plain
  props down. Don't lift a whole page to the client for one interactive widget.
*Why:* smaller bundles, faster first paint, SEO on public pages.

### Data tables - see `reference/data-tables.md`
- Every admin list/table is **TanStack Table in manual mode** over the
  paginated endpoints: the server owns the data, the URL owns the view state
  (`page`, `limit`, `sort`, `search`, filters, via the one `useTableParams()`
  hook), TanStack owns column defs + row model, and rendering goes through
  mobile-first-ui's dual-render pattern.
*Why:* back/share/refresh reproduce the exact view; tables are never improvised.

### Forms & validation
- react-hook-form + `@hookform/resolvers/zod`; schema in `validations/`.
- The **frontend Zod schema mirrors the backend** validation for that endpoint
  (document the mirror in a comment) so client and server agree.
*Why:* instant client feedback with the same rules the server enforces.

### Complex forms - see `reference/complex-forms.md`
- Multi-step wizards: ONE form instance + ONE schema, per-step `trigger()`,
  submit only on the final step. Repeating rows: `useFieldArray` with keys
  from `field.id`. Dirty forms get `useUnsavedChangesGuard(isDirty)`; no
  autosave unless the spec demands drafts.
*Why:* wizards and array forms have one canonical shape; improvising forks the UX.

### Dashboards - see `reference/dashboards.md`
- recharts themed via `--chart-*` CSS tokens (never hex in chart code), house
  Intl formatters on every axis/tooltip, skeleton/error/"no data yet" per
  tile, and every chart paired with accessible data.
*Why:* charts stay theme-correct, readable, and honest in every state.

### UX states (loading / error / empty)
- Every `useXQuery` consumer handles `isLoading` (skeleton - reuse `*Skeleton`
  components), `isError` (error UI), and **empty** (no-rows state) explicitly.
- Mutations route errors through a **shared RTK-Query-error → message** helper and
  show a toast; never swallow.
*Why:* no blank/janky screens; consistent failure UX.

### Types
- Request/response interfaces (`I*Response`, `I*QueryParams`) live in `types/` and
  are shared by the api slice and components. Never inline a response shape.
*Why:* one source of truth; refactors are type-checked end to end.

### Env
- Read `NEXT_PUBLIC_*` through the typed `PUBLIC_ENV` module (mirror of the
  backend `ENV`) that throws on missing values at module load - so
  misconfiguration fails at the first evaluation (usually the build/prerender;
  at worst, immediately and loudly at module load) instead of as a silent
  `undefined` baseUrl. Every file reads `PUBLIC_ENV.*`, never `process.env.*`.
*Why:* misconfiguration is caught before users hit broken behavior.

### Hygiene
- **No `console.*` in shipped code.** Remove debug logging or route it through a
  dev-only logger. Keep doc comments truthful.
*Why:* console noise leaks internals and clutters production.

---

## When unsure
If something looks like a deliberate choice vs. a smell (e.g. a client page that
could be a Server Component), ask rather than guess. Read the relevant reference
file before writing the data layer, a table, a form, or a dashboard.
