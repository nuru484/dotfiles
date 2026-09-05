---
name: khadys-dev-testing-notes
description: "How to browser-test khadys-kitchen locally — rate-limit bypass header, OOM constraint, mobile card-list pattern"
metadata: 
  node_type: memory
  type: project
  originSessionId: 71a86592-a104-4508-9fae-b7a945aa9f01
---

Browser-testing khadys-kitchen locally (as of 2026-07-13):

- The backend honours an `X-Rate-Limit-Bypass: <secret>` header (secret in
  backend `.env` `RATE_LIMIT_BYPASS_SECRET`); send it from Playwright via
  `extraHTTPHeaders` to skip all rate limits. It is in the CORS
  `allowedHeaders` list in `src/app.ts` — needed for browser fetches.
- The WSL2 box has ~8GB RAM; running two `next dev` servers (e.g. agritrade +
  khadys) plus a build gets the khadys server OOM-killed silently. Check
  `dmesg | grep -i oom` when localhost:3000 dies. Another session's
  agritrade-frontend may hold port 3000 — khadys then runs on 3001 (backend
  `.env` CORS_ACCESS already includes both 3000 and 3001).
- Frontend mobile convention (introduced 2026-07-13): admin list pages render
  `RowCardList`/`RowCard` card stacks below `md` and the `<table>` (wrapped in
  `hidden md:block`) from `md` up — primitives in
  `src/components/admin/table-bits.tsx`; each page shares one `menuItemsFor()`
  between table and cards. `Modal` is a bottom sheet below `sm`. See
  [[khadys-kitchen-role-rules]].
