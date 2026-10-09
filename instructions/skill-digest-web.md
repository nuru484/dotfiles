# Web skill set, in one page

Reading this satisfies the web skill gate. Load a full skill only when a
change turns on its concern (a new table engine, a redesign, a tricky
overlay); project rules (CLAUDE.md, docs/PATTERNS.md, DESIGN-RULES.md, the
repo's codebase guide) win.

## frontend-conventions
- Inspect the nearest working route, slice, form and component first; reuse.
  Server-only code stays out of the client graph; small client boundaries.
- Client data through the existing RTK Query apiSlice (injected endpoints);
  no second cache, no server data copied into local state. Mutations go to
  the Express API, no Server Actions.
- Forms: react-hook-form + Zod as the project does; keep API nullability.
- Route files export only allowed fields; helpers live in feature modules.
  After adding routes run typegen, and run `next build` once before push.
- Verify cache invalidation and loading/error/empty/submitting states.

## mobile-first-ui
- Design the smallest width first (280/344); no horizontal page scroll at
  any width; check 1440/1024/768/390/344 live, with max-length data.
- Inside the app shell size by container (`@container/main`), not viewport.
- Tables: dual render (row list below md, table from md); one stretch
  column capped at 40%; truncated cells carry `title=` and a detail page.
- Badges only for short system enums, never user-authored text.
- Below sm, free text and its controls never share a row; stack them.
- Containers dissolve on phones (one inset level); key/value rows stack
  below ~480px; values `min-w-0 [overflow-wrap:anywhere]`.
- Single-line ellipsis in grid/flex-col: `min-w-0 line-clamp-1
  whitespace-normal [overflow-wrap:anywhere]`, not bare `truncate`.
- Modals are bottom sheets below sm; harden dialogs at the primitive.
- Inputs >= 16px on mobile, `dvh` not `vh`, touch targets >= 44px, no
  hover-only reveals.

## api-contracts
- Envelope `{ message, data }`, lists add `meta {total,page,limit,totalPages}`;
  errors `{ status:"error", message, code?, details? }`; branch on `code`.
- ISO date strings; money as integer minor units + currency; null = cleared,
  omitted = not provided. Same param names both ends (page, limit, sort,
  search, typed filters). A shape change touches both ends in one change.

## design-taste
- On existing screens hold the design system steady; no restyling, no new
  visual language, no shadows unless asked. Never invent facts or content.

## web-design-guidelines
- For changed interactive UI: labels, semantics, keyboard, focus, contrast;
  fix defects in scope. Owner rules (badges, widths, 44px) win.

## emil-design-eng
- Immediate feedback, focus preserved, interrupted actions converge, loading
  and failure keep the next action clear; smallest fix, no gratuitous motion.
