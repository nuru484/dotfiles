---
name: page-parts-share-measure
description: "A page's header buttons, tiles and list end at one edge; messages read at a measure; files are tiles; remove = X icon with tooltip everywhere (owner 8 Oct)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 7134d0d2-3d09-4e60-8c47-59cb7e6774ed
  modified: 2026-10-08T10:45:26.758Z
---

Owner, 8 October 2026:
- A page's parts end at the same edge: a header button never stands at the window's edge beside a narrow list, and a list under full-width figure tiles runs their width. Fixed in the primitives (PageHeader `:has(~[data-measure=record])`, SectionList standalone widens under `[data-slot=figure-tiles]` and in the portal `[data-lists=wide]`).
- Messages are read by people: each message bubble is held to a measure (max-w-3xl, text max-w-prose), long ones fold with "Show more" (`MessageText`).
- Attached files are compact tiles (`FileTiles`/`FileTile` in shared/file-tile.tsx), never full-width rows; taking a file off is the X icon with a "Remove" tooltip in the portal and the console alike.
- Tab rows use the strong border token so the rule under tabs is visible on the page ground.

**Why:** the owner saw buttons and lists out of line, wall-of-text messages, and the portal and console disagreeing on the remove control.
**How to apply:** any new page, thread or attachment list uses these primitives; check alignment of header, tiles and list in the live walk. Related: [[detail-list-rows]], [[portal-reuses-console-kit]].
