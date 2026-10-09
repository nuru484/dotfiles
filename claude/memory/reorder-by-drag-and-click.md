---
name: reorder-by-drag-and-click
description: Owner rule 30 Sep: anywhere items move up/down, support drag and drop as well as the Move up/down actions, as the workflow template steps tab does
metadata:
  type: feedback
---

Owner, 30 Sep 2026: every ordered list with Move up / Move down (pipeline stages, pipeline checklist, assignment rules, and any other) also supports dragging, the way the workflow detail page's Steps tab does (shared `drag-handle.tsx`).

**Why:** clicking one place at a time is slow for long lists; drag is the expected gesture.

**How to apply:** build ordered lists on the shared drag handle from the start; sweep for "Move up" when touching reorderable lists. Related [[detail-views-not-forms]].
