---
name: files-open-in-viewer
description: LFMS - every file opens in the in-app viewer before download; only actions labelled Download save directly
metadata:
  type: feedback
---

Every document/file (certificates, scans, statements, letters, PDFs) opens in the browser first, in the shared viewer (`FileStage` via `fileOpener()` in lfms-web `src/lib/files.ts`), never a blind new tab or download. Only an action whose label says Download saves at once (`fileOpener({ download: true })`).

**Why:** owner, 7 Oct 2026: "all documents should be openable in the browser, before a user can decide to download... unless the button or action is explicitly saying download."

**How to apply:** new file actions call `fileOpener()`; label view actions "View"/"Open", not "Download". Related: [[detail-views-not-forms]].
