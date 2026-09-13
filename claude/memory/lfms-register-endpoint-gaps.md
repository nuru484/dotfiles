---
name: lfms-register-endpoint-gaps
description: LFMS API endpoints that cannot answer the console screens wired against them (found 2026-09-07; four closed by M30 the same day, one open)
metadata:
  type: project
---

Five LFMS API gaps found while wiring the console registers to server-side
search, filtering and paging on 2026-09-07. API M30 closed the first four
(walls state, typed code/currency summaries, users status sort, login
attempts search/filter/order) and web commit ff6474e dropped their
stand-ins the same day. Only the originals stale-days gap below is still
open. History of the closed four is kept for the shape of the rule.

- `GET /ethical-walls` filters by `state` but the row carries only `isActive`
  and `liftRequestedAt`, so the standing badge is still derived on the client.
  The derivation cannot be deleted until the response carries `state`.
- `GET /codes/*` and `GET /currencies` publish an untyped `summary`. The
  "N in use" figures on the three code cards were counted from the page in
  hand, which became wrong once the screens paged; they were removed rather
  than left lying.
- `GET /users` refuses a `status` sort though the column offered one.
- `GET /users/{id}/login-attempts` only pages: it ignores search, outcome and
  period, so those controls are hidden by a `scope` prop rather than drawn.
- `GET /originals/outstanding` (found 2026-09-07, W24) carries no stale-days
  figure on its wire, unlike `/stale-matters` whose `summary.days` does. The
  web reads `documents.original_stale_days` from `GET /settings` under
  `setting.read` and names no figure for anyone without it. Fix: publish
  `summary: { staleDays }` on the report and delete `use-stale-days.ts`.

**Why:** each one is a screen the console cannot fully serve yet, and the
client-side stand-ins are the exact shape of bug the register rules exist to
prevent.

**How to apply:** when Phase 5 documents work resumes, fix these in the API
first and delete the corresponding web workaround in the same change; see
[[lfms-ui-structure-principles]].
