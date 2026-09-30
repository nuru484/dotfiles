---
name: phone-content-first
description: "Phone UI - content first; fold record actions into one menu, no lone controls on empty rows, words over icons where room allows; system-wide in shared components"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f517216b-3822-4aa9-a77a-c5c7311d844b
  modified: 2026-09-28T17:21:12.171Z
---

On phones the reader must reach the content without scrolling past rarely used controls, and no row may look half-empty. Owner's rules (28 Sep 2026), now in lfms-web `docs/DESIGN-RULES.md` ("The phone reaches the content first"):

- A record header folds every action into one menu at the end of the subheading's row; the subheading is the short name only, one or two lines as it needs (don't force one line).
- A lone control takes the row's width; controls sharing a row share its width (equal unless words need more), wrapping only when they don't fit. Applies to secondary tabs, toolbar buttons, section buttons like Copy.
- Icon-only only where the row lacks room (Filters keeps its word unless a search box shares the row); a stretched button never shows an icon alone.
- A register's own menu icon keeps its border; a lone one sits on the search row.
- Record pages: two columns only when the main column grows; a notice-plus-facts record (exports, downloads) uses `RecordLayout width="brief"` (one column, 60% on wide); don't draw a card that only says "nothing here" once finished.
- Loading skeletons: measured from the loaded page (cards, columns, descriptions, stacked rows, lists, width, header meta/actions), never guessed; `RowsSection` object form in skeletons.tsx.
- One set of dots per page: a record nested in another record's tabs keeps its actions as buttons (`InsideRecord`).

**Why:** the owner found stacked "storey" rows, lone left-pinned buttons and bare stretched icons ugly and wasteful, and wants every fix system-wide so it never recurs.

**How to apply:** fix the class in the shared primitive (PageHeader, PageTabs, DataTableToolbar, RowActions), sweep for other instances, record the rule in DESIGN-RULES, and check live at 280/344. Related: [[check-ui-live]], [[fix-the-class-not-the-instance]].
