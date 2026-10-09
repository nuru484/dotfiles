---
name: skeletons-follow-content
description: Every UI change updates its loading skeleton to the new shape (rail, table columns, cards), never a generic placeholder (owner, 6 Oct 2026)
metadata:
  type: feedback
---

When a screen's layout changes, its loading skeleton changes with it in the same commit. Each skeleton is drawn for that screen and looks like the content it stands in for: a rail beside a table, the table's columns, the record's rail cards.

**Why:** the owner asked, 6 Oct 2026: "keep and ensure the skeletons are also updated and bespoke and looks like the content it's coming to display."

**How to apply:**
- Fix the shape at the shared primitive where one exists: `DataTable`'s loading branch, `RecordSkeleton` with `table:N` sections and a rail through `aside`.
- Give a page-level skeleton the page's own columns when it loads before the table does.
- Check the skeleton whenever you check the screen live ([[check-ui-live]]).
