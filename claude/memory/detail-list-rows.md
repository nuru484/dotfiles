---
name: detail-list-rows
description: LFMS lists inside detail-page sections - name + status badge on line 1, description on line 2, nothing else; never label/value facts or dot-joined facts; the row opens details (dialog for short, page for rich)
metadata:
  type: feedback
---

A list in a detail page's section that is not a table reads, per row:

    nnnnnnnnnnnnnnnnnnnnnnnnnnnn  [status]          (actions icon)
    ddddddddddddddddddddddddddddddddddddddddddd

n = the item's name or primary thing; status = a badge where it has one; d = its description, where it has one. Never key/value pairs ("Role Owner  Matters 1") and never facts strung with dots ("In · 25 min · Ama"). The row does not try to show everything: the whole row (or the actions menu's View details) opens the rest, in a dialog for short content, on its own page or inline for rich content. Tables with column headings are fine as they are.

**Why:** owner, 8 Oct 2026, rejecting both the dot-joined and the labelled-facts rows: "the list rendered like that should not try to show everything, that's why it gets the detail view in the dialogs or its own pages". Good examples: matter Overview > Notes, matter Parties.

**How to apply:** held in `SectionRow` (lfms-web shared/section-list.tsx): facts go to the details dialog, never on the row. Sweep every list on every detail page, the client portal included. Related: [[detail-views-not-forms]], [[fix-the-class-not-the-instance]].

**9 Oct 2026 additions (owner):** no kind icons and no file-count icon on rows; who/when moves to line 2 unless line 2 is prose (notes); statuses use their real tone (positive green: sent, cleared, verified). Table vs list: short values that read whole -> table with headings; values that would truncate -> list rows + details dialog (a truncating table still gets a details dialog). Every titled section has a one-line sentence of 5+ words (guarded in section-subheading-length.test.ts); if title + one-line sentence + controls don't fit, controls take the next row. Rules recorded in lfms-web/CLAUDE.md "Detail-page lists and section headings".

