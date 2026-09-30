---
name: lfms-handoff-2026-09-28
description: "LFMS state 29 Sep 2026 — owner's fixes (roles, courts, list search) nearly done on main; next is the owner's offices and bank accounts spec talk, then H1, then Phase 11 after discussion"
metadata:
  node_type: memory
  type: project
  originSessionId: 7239d7a3-327e-4e89-aeb1-96ea371ea276
  modified: 2026-09-29T03:03:06.510Z
---

- Done and pushed: ranked cumulative roles (one role per person, inheritance
  lines MP > Partner/Accountant/Firm admin/Compliance; Partner > Associate >
  Trainee > Paralegal; Accountant > Bookkeeper; Firm admin > Secretary),
  holder limit (MP 1) in use case and DB trigger, transfer flow; scopes nest
  own < supervised < practice_area < all; courts sorted by level, one
  Supreme Court (partial unique index), two-column court pages, separate
  class/court dialogs; rail first on phones in RecordLayout.
- List search sweep committed and pushed on main in both repos,
  29 Sep: shared helpers `src/platform/http/list-filters.ts` (API) and
  `useDebouncedValue` (web); guard `lists-are-paged.test.ts` NO_SEARCH.
- Done 29 Sep: CPD and practising status paged; all pushed. Open:
  CPD lawyer picker reads the first 100 lawyers (ponytail note in code);
  the budget report API (`GET /matter-budgets`) has no web screen.
- Next, as TODO items in both repos (29 Sep): O1 offices and bank
  accounts, talked through with the owner before any code; F1 budget
  report screen; F2 searched pickers for every growing dropdown; F3
  search and filters on the lists under a record; then H1; then Phase 11
  after discussion ([[lfms-discuss-before-payments]]).
- The owner asked (not decided) whether the order after Phase 11 is right;
  I answered: portal after payments is right; practice modules (14) before
  reporting (13); pull migration forward if a firm is to go live sooner.
- Known flake: web `profile-headers.test.tsx` 1536 snapshot under load.
