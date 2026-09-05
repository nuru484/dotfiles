---
name: agritrade-cash-book-deploy
description: AgriTrade prod DB migration state and the landed-cost / held-account work pushed 2026-08-16
metadata: 
  node_type: memory
  type: project
  originSessionId: bc6e18a2-7208-4403-8c44-7187abf15bd4
  modified: 2026-08-16T23:20:06.241Z
---

Prod (Neon "neondb") is migrated through `20260817140000_one_held_pot_per_tender` as of 2026-08-16 evening, and both repos' `main` are pushed to match, so prod code and schema agree again (the earlier "old code on new schema" gap is closed).

Landed on 2026-08-16: LandedCostMovement ledger (costs capitalised into goods, released at dispatch/transfer/shrink), agent + admin can attribute a cost to a purchase, partial unique index one held pot per person per tender, purchase-cost console + field form.

**Why:** the user migrates prod by hand before pushing (see [[no-migrations-in-deploy-scripts]]); knowing exactly where prod stands avoids re-auditing.

**How to apply:** before the next push, `git diff origin/main --name-only -- prisma/migrations` and check `_prisma_migrations` on prod; audit for DROP/DELETE/SET NOT NULL; the CSV backup dir in the scratchpad is session-only, take a fresh one. Still user-side: classify expense categories (cost of sales / admin / finance) in the console - deliberately not backfilled. Suspense/till balances still need reclassifying. Open question left with the user: confirmation dialog on the agent purchase form.
