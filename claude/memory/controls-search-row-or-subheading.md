---
name: controls-search-row-or-subheading
description: LFMS: one control size in headings and toolbars; tabs never repeat their name; a list with a search box puts its buttons/filters on the search row (filters as tooltip-labelled inline); only search-less pages side buttons with the subheading; subheadings max 2 lines, ~60-70% width; sub-tab sentences under the sub-tabs
metadata:
  type: feedback
---

Owner, 1 Oct 2026 (fix round before S8):
- Search box present: subheading reads above it alone; Add/buttons/filters end the SEARCH row. No search box: buttons or the actions menu sit beside the subheading. Guard: `heading-actions.test.ts` ("end the search row").
- A filter on the search row shows its label as a tooltip, never a legend above (toolbar wraps actions in the inline FilterPresentation).
- Subheadings wrap at most 2 lines beside controls at EVERY width: the column widens past 60% if that holds it to 2 lines, else the controls drop to the next row (`useFitsBeside` sentenceRef/capped). Prefer one line at 60-70% for tab sentences (shorten them).
- A primary action stands as a button beside its actions menu on one row (enquiry Move + dots; tax group Add component + dots).
- A sentence that belongs to a sub-tab reads under the secondary tab strip, not above it (`PageTabFrame secondary`).
- Content that is key/value or switch matrices gets a max width on big screens (notifications max-w-4xl); a promoted button ends where the content ends (`useTabPageMeasure`).
- One register in one place: firm bank accounts live only in Banking (Settings > Firm > Bank accounts redirects).
- Sidebar names "Client intake", not "Intake".
- ONE control size for a list's search, filters and buttons, in a section heading or a toolbar (owner, 1 Oct, round 2): ButtonScale "section" == "page" (guard in button-sizes.test); no `size="sm"` on a labelled button in a heading or empty state; small only for in-row/inline controls (Show more, Mark read, form-line Remove, alerts).
- A record tab never repeats its own name as a heading inside it: the tab is the heading, the content opens on its sentence (TabLead).
- Time zone and language fields are dropdowns (`components/settings/zone-and-locale.tsx`), never typed; the API refuses unknown zones (`timeZoneField`).

**Why:** consistency system-wide; the owner reads misplaced controls as different patterns.
**How to apply:** check every new list/tab against these before calling it done. Related: [[lists-controls-one-place]], [[lfms-tab-subheadings]], [[fix-the-class-not-the-instance]].
