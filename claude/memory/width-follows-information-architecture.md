---
name: width-follows-information-architecture
description: "LFMS: a page's width follows its information architecture; key-value sections never stretch full width (rows read at 600-800px); copy the judge record, general settings and numbering pages"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fd6045f7-4a8c-47a2-ae49-5befc426edac
  modified: 2026-09-30T06:51:26.965Z
---

Key-value content (label and value rows, a details section with its Edit button) is never stretched across the whole page. Rows read best at roughly 600 to 800px; a full-width section leaves the value 600px from its label with 1,200px of empty row after it, and detaches the Edit button from the fields it controls. Use the width the information needs: the judge record, Settings > General and Settings > Numbering are the references. Wide content (registers, tables, grids) may take the width; facts and forms take a measure.

**Why:** owner, 30 Sep 2026, after the court page (tabs, S1) and the bank account detail tabs drifted to full-width sections: "it breaks ux, and even the ui looks"; "keep it in memory to never repeat that again".

**How to apply:** before shipping any record or settings page, check the widest section at 1536: a section of rows must sit in the record layout's measure or a two-column (main + rail) layout, never one card spanning the window. Fix it in the shared layout primitive where possible. See [[lfms-ui-structure-principles]], [[check-ui-live]].

**Page measures (owner, 4 Oct 2026):** registers and tables take the 2304px page measure; record (detail) pages hold to 1360px on any screen, header and tabs included (shell and tabbed frame narrow when `[data-record-layout]` is present). A page measure change must never widen record pages again.
