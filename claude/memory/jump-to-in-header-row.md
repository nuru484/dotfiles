---
name: jump-to-in-header-row
description: "LFMS: the page's Jump to sits in the header's action row as a ghost button with a dropdown, left of the actions icon; sticky bar on scroll with heading, Jump to (showing the section in view) and actions; one shared component"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fd6045f7-4a8c-47a2-ae49-5befc426edac
  modified: 2026-09-30T06:51:31.166Z
---

A long page's "Jump to" navigator is not a row of its own under the heading. It sits on the header's action row, left of the actions (dots) icon, as a ghost button with a dropdown that reads its text. As the page scrolls, a sticky bar holds the heading on the left and Jump to plus the actions on the right; the button's text follows the section in view, and after a jump it reads the section jumped to. Built once as a shared component so every page gets it.

Exception: where Jump to shares a row with a search box and filters that balance it (the role record's permission matrix), it stays there.

**Why:** owner, 30 Sep 2026: alone on its own row it is the first thing a reader sees, yet it is navigation, not content.

**How to apply:** never place the navigator as a standalone row; use the shared header navigator. See [[width-follows-information-architecture]], [[phone-content-first]].
