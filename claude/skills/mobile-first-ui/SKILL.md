---
name: mobile-first-ui
description: >-
  Mobile-first UI/UX principles for every frontend the user builds — ~90% of
  real users are on phones, so the phone layout is the primary design, not an
  afterthought. Apply AUTOMATICALLY and ALWAYS on ANY frontend work: creating
  or modifying pages, components, lists/tables, cards, forms, modals,
  toolbars, detail views, navigation, or styling — in any project, any stack.
  Also apply when reviewing UI. "Looks good on desktop" is never an excuse:
  if it degrades on a phone it is broken. Covers responsive structure and
  worst-case content hardening. The user checks the rendered UI themselves
  and will request visual adjustments - do NOT run dev servers or take
  screenshots to self-verify UI.
---

# Mobile-First UI

The 280px view (Galaxy Fold cover) is the primary design target; desktop is
the enhancement. Never suggest "use desktop for the best experience" — users
don't adapt to the app, the app adapts to them. These rules come from real
post-deployment complaints; reference implementations are
`~/repos/khadys-kitchen-frontend` (2026-07: toolbars, dual tables, row
lists) and `~/repos/traveltrek/frontend` (2026-07: container-query shells,
`DetailPageHeader`, `FilterBar`, `Money`, clamped comboboxes) — copy their
patterns, don't rediscover them.

## Definition of done (non-negotiables — check every one before "done")

```
[ ] No document-level horizontal scroll at 280px, 375px, ~768px, desktop
[ ] Every component's mobile arrangement was DESIGNED, not inherited from wrap
[ ] Max-length content in every field renders gracefully (see worst-case)
[ ] Money/primary figures never truncate — secondary meta gives way
[ ] Tables have a card/row-list view below md (never scroll-only)
[ ] Dashboard content verified at 768/1024 WITH the sidebar open — that is
    the default view; "hide the sidebar to read it" = broken
[ ] Truncated/clamped text is reachable in full somewhere (detail page/tooltip)
[ ] Data-table column widths follow the width-share rules below
[ ] Zero user-authored text inside a Badge/pill anywhere in the change
[ ] No row where free text and action buttons share the width below sm
```

## Data-table column width rules (2026-08 Elektor Pro, user-mandated — apply to EVERY data table)

- Exactly ONE primary column per table is marked as the stretch column; it
  claims **40% of the table width** (`w-2/5` th + `w-2/5 max-w-0` td) — **no
  column may ever exceed 40%** of the table.
- Inside the stretch cell, text truncates at **`max-w-[90%]`** of the column
  (85% when an avatar sits beside it) — content uses the room available but
  never runs to the column edge, and never forces horizontal scroll.
- Secondary long-content columns get fixed caps via a shared `CellText`-style
  cell (block min-w-0 truncate + max-w + `title` tooltip). Bare `truncate`
  in a td WITHOUT a width cap does nothing — the column stretches instead.
- Every truncated cell carries the full value in `title=` and the detail page.

## The badge rule (hard, user-mandated)

Badges/pills are ONLY for short (~≤20 chars) system-generated enum values —
statuses, "You", "No. 3". **User-authored text (names, groups, categories,
portfolios, nicknames, titles) is NEVER rendered in a badge**, in tables,
cards, chips, rails, or anywhere else. Free text gets plain typography with
truncation or wrapping (`[overflow-wrap:anywhere]`). Multi-value user text
(e.g. group memberships) renders as a plain list or comma-joined truncated
line — not a chip row.

## No width competition on phone rows (hard, user-mandated)

Below `sm`, free-form text and its action controls (edit/delete icons,
buttons, selects) must NOT share a horizontal row — the controls squeeze the
text into a sliver. Stack them: text block first, actions on their own row
above or below (`flex-col sm:flex-row`). Applies to list rows, card headers,
criteria/setting rows, and page headers whose title can be long (title takes
the full width; buttons move to their own row).

## Container queries, not viewport breakpoints, inside app shells

The #1 source of rework. In any layout with a persistent sidebar (admin
dashboards), `md:`/`lg:` fire on the VIEWPORT while the sidebar eats
~256px — so an iPad at 768px gets the "desktop" grid squeezed into 512px
of content. Anything inside the shell (grids, stat tiles, toolbars,
detail columns, filter panels) must size by CONTAINER:
- Make `<main>` a named container (`@container/main`) and use
  `@2xl/main:grid-cols-2`, `@4xl/main:grid-cols-4`, etc.
- Self-contained cards (filter panels, sheets) get their own `@container`
  and pair short fields 2-up via `@[280px]:grid-cols-2` — width thresholds
  measure the CARD, so the same component works in a 375px sheet (sided)
  and on a fold (stacked) without media queries.
- Viewport breakpoints remain correct only for viewport-anchored chrome
  (the sidebar itself, bottom tab bars, sheet-vs-dialog switching).

## Layout structure

- **Design at 280px first, enhance upward.** If you haven't consciously
  decided what a component does at 280px, it isn't done.
- **Containers dissolve on phones (Facebook-style).** Max ONE level of
  horizontal inset below `sm`. Cards in padded pages go full-bleed
  (`rounded-none border-x-0`, negative-margin to the page gutter, or
  restructure) with dividers instead of borders. Nested box-in-box padding
  can eat 30% of a 280px screen before content renders. Page gutters shrink
  on phones (12–16px, not 24–32px).
- **No unintentional negative space.** Empty reserved slots, blank columns,
  uneven gaps = bugs. Density on mobile is compact and even.
- **Key/value rows stack on phones.** Label-left/value-right only where room
  is guaranteed; below ~480px the label sits above the value
  (`flex-col` → `min-[480px]:flex-row justify-between`). Values get
  `min-w-0` + `break-all` (unbroken tokens) so they never make labels hang.
- **The forgotten middle:** verify ~600–800px too, not just 280 and desktop.

## Component patterns (implementations in khadys-kitchen-frontend)

- **Tables → dual render.** Below `md`: dense card/row list showing ALL row
  data; from `md`: the real `<table>` (`hidden md:block`). One shared
  `menuItemsFor()`. (`src/components/admin/table-bits.tsx`.)
- **List rows: two dense lines, messaging-app style.** Line 1: title
  (truncate) + key figure right (`flex-none` — never truncates). Line 2:
  meta (truncate) + compact badges. `py-2.5`, inline action menu, skeletons
  matching real density.
- **Toolbars:** search always visible and full-width on phones; row 2 =
  Filters toggle left, count + actions right; filters always behind the
  toggle on phones; 3+ actions collapse behind an "Actions" toggle panel.
  Desktop-spread filter rows must NEVER just wrap on mobile.
- **Modals: bottom sheets below `sm`** (slide up, full width, safe-area
  padding, internal scroll so the submit is always reachable), centred card
  from `sm`. Footer buttons stack full-width on phones, primary on top.
- **Harden dialogs at the ROOT primitive, not per call site.** Dialog/
  AlertDialog/Modal titles and descriptions interpolate user-authored names,
  so the shared Title/Description components carry `min-w-0 max-w-full
  [overflow-wrap:anywhere]`, and Content carries `max-h-[calc(100dvh-2rem)]
  overflow-y-auto`. Fixing one overflowing dialog inline is a smell - the
  next dialog will overflow the same way.
- **Cards in grids: uniform height.** Titles `line-clamp-2` WITH space
  reserved (`min-h-[2.4em]`), descriptions `line-clamp-2 min-h-[3.2em]`,
  optional meta lines always rendered. Full text on the detail page +
  `title=` tooltip. **Never `flex-1` a line-clamped box** (stretching
  repaints the hidden lines) — pin footers with `mt-auto`.
- **Badges are for predefined, short, enum-like values ONLY** (statuses:
  Published, Draft, Paid…). Never render admin-editable free text (item
  names, custom categories) in a badge — long text in a pill looks bad at
  every screen size. Free text gets plain typography with truncation.
- **Detail pages:** length-adaptive display type (`detailTitleCls`,
  `statValueCls` in `src/components/admin/ui.tsx`) so 150-char names and
  huge amounts render calmly; stat tiles 2-up from 360px; images full-width
  banner crop on phones (never a fixed thumb with dead space beside it);
  page titles `line-clamp-2` not `truncate`; a single leftover action
  renders as a button, not a one-item "More" menu.
- **Forms:** native date inputs render blank on mobile — overlay a
  placeholder (`DateInput`). Inputs full-width; buttons wrap as whole pills
  (`flex-wrap` + `whitespace-nowrap`), never wrapping their label text.
  Pair short related fields (name+type, check-in+check-out, year+month)
  2-up via container query with a 1-col fold fallback. Number inputs must
  NOT clamp in `onChange` (`Math.max(1, parse(v)||1)` makes the field
  impossible to clear) — hold the raw string, clamp on blur and on submit.
- **Selects & comboboxes (shadcn):** `SelectTrigger` defaults to `w-fit` —
  in forms always `w-full min-w-0`. The selected value must clamp to ONE
  line with the safe recipe below; a value taller than the fixed-height
  trigger gets flex-centered and PAINTS OVER content above and below it.
  Dropdown items show the primary name only (no description second line),
  wrapped with `[overflow-wrap:anywhere]`; popover/content width stays
  capped (`max-w-[min(92vw,26rem)]` or trigger width).
- **Page/section headers:** one shared header component, never per-page
  copies (they drift). Right-side controls (back link, Filters) align to
  the TITLE row only — never straddling title+description; if title and
  control can't share the row without wrapping, the control moves ABOVE
  the title (the mobile arrangement). Back controls are plain links
  (no border, no hover bg, underline on hover). Cap header + page width
  (`max-w-7xl mx-auto`) so nothing grows unbounded on large screens.
- **shadcn Card double padding:** `Card` ships `py-6`; adding your own
  `CardContent` padding doubles the vertical so y-padding visibly exceeds
  x-padding. When CardContent carries padding, set `py-0` on the Card and
  keep x = y (`p-4 sm:p-6`).
- **Compact money at scale:** amounts ≥ 1M render compact (₵24.5M) on
  cards/tables/tiles with the exact figure in a `title` tooltip and on the
  detail view — 8-digit exact figures are what break tile layouts.

## Mobile platform gotchas

- Inputs need `font-size ≥ 16px` on mobile or iOS zooms the page on focus.
- `100vh` is broken in mobile browsers — use `dvh`; safe-area insets
  (`env(safe-area-inset-*)`) on anything pinned to a screen edge.
- Hover doesn't exist on touch: no hover-only reveals; give taps `active:`
  feedback.
- Fixed/sticky elements: bottom bars need content bottom-padding so the last
  item isn't covered; sticky headers must not eat half a 653px viewport;
  toasts must not cover the primary CTA.
- Touch targets ≥ 44px and not packed against other targets.

## Worst-case content hardening

Assume every field at its validation max (150-char names, 255-char UNBROKEN
emails, 1000-char notes, max-int amounts):
- **Standardize on `[overflow-wrap:anywhere]`** (or `break-all`) + `min-w-0`
  for unbroken tokens — `overflow-wrap: break-word` (Tailwind `break-words`)
  wraps visually but does NOT shrink min-content, so flex/grid ancestors
  still stretch past the viewport.
- **Never combine `break-words` with `[overflow-wrap:anywhere]`** — they set
  the SAME property and whichever is later in the generated CSS wins, so
  `break-words` can silently disable `anywhere` and reintroduce the
  min-content stretch. One or the other, and it should be `anywhere`.
- **The single-line-ellipsis trap:** `truncate` sets `nowrap`, which makes
  the text's min-content its FULL width — in grid tracks, flex-col parents,
  and buttons it stretches the whole form/track even with `min-w-0`. Safe
  single-line recipe: `min-w-0 line-clamp-1 whitespace-normal
  [overflow-wrap:anywhere]` — one visual line with ellipsis, ~1-char
  min-content. Plain `truncate` is only safe on flex-ROW items whose
  parent's width is already pinned.
- `min-w-0` on any grid/flex item holding user text (automatic minimum size
  is the #1 phantom-overflow cause).

## Verification

The user reviews the rendered UI themselves and will report what to adjust.
Do NOT start dev servers, drive the app with Playwright, or take screenshots
to self-verify UI work. Apply the rules above at write time; when the user
reports a visual issue, fix it from their description.

## Scope boundary

Responsive structure + content resilience only. Aesthetic
direction → `frontend-design`; a11y/perf audit → `web-design-guidelines`;
stack conventions (data layer, forms, files) → `frontend-conventions`.
