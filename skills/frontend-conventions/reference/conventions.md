# Detailed conventions

Apply only the sections relevant to the requested change. Existing project
architecture and installed APIs take precedence over these house defaults.

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

### Data layer (RTK Query) - see `data-layer.md`
- One `redux/api-slice.ts` owns `createApi`, `fetchBaseQuery` (`credentials:"include"`),
  the Mutex-guarded **silent token refresh**, and `tagTypes`.
- Feature files (`redux/<feature>-api.ts`) call `apiSlice.injectEndpoints`.
- Queries `providesTags`; mutations `invalidatesTags` so lists stay fresh.
- Build query strings with a typed helper (`buildDateRangeUrl`-style), never ad hoc.
*Why:* one cache + one auth path; cache correctness is declarative, not manual.

### Components & rendering - see `components-forms.md`
- Server Component by default; `"use client"` only on interactive leaves.
- Fetch data in Server Components (or via RTK Query in client islands); pass plain
  props down. Don't lift a whole page to the client for one interactive widget.
*Why:* smaller bundles, faster first paint, SEO on public pages.

### Data tables - see `data-tables.md`
- Server-paginated admin tables use **TanStack Table in manual mode** over the
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

### Complex forms - see `complex-forms.md`
- Multi-step wizards: ONE form instance + ONE schema, per-step `trigger()`,
  submit only on the final step. Repeating rows: `useFieldArray` with keys
  from `field.id`. Dirty forms get `useUnsavedChangesGuard(isDirty)`; no
  autosave unless the spec demands drafts.
*Why:* wizards and array forms have one canonical shape; improvising forks the UX.

### Dashboards - see `dashboards.md`
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


## House library choices when a capability is needed

Preserve installed suitable libraries. For a new unmet need, house preferences are
TanStack Table for server-driven tables, recharts for charts, Virtuoso for measured
large-list rendering issues, dnd kit for drag/drop, cmdk for a command menu,
next-themes for theme switching, input-otp for OTP fields, and Sonner for toasts.
Verify current compatibility before adding a dependency. Do not install this list
as a bundle or create those features just because the choices are documented.
