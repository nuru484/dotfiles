---
name: traveltrek-upgrade
description: "TravelTrek was upgraded to the khadys standard on 2026-07-16 — 24 local commits on main, NOT pushed; key facts for future sessions"
metadata: 
  node_type: memory
  type: project
  originSessionId: a8d47fda-3457-49c2-b2b0-22b47d7f75d2
---

~/repos/traveltrek (backend/ + frontend/ in one repo) was fully upgraded to the [[agritrade-backend-project]] / khadys-kitchen standard on 2026-07-16: ESM `#*`/`#types/*` imports, DI service factories (AppDeps/defaultDeps), zod at the route boundary, refresh rotation + tokenVersion, soft deletes, money in **integer pesewas** end-to-end, Customer separated from staff User (dual-principal JWTs with `kind`), OTP passwordless login + minimal signup (name + email|phone) + Google sign-in + forgot/reset. Backend: 234 vitest integration tests against real `traveltrek_test` DB. Frontend: 80 vitest/RTL tests, RowCardList/RowCard mobile tables, proxy.ts hint-cookie gate.

**Why:** the repo previously had no tests/CI/lint and fat controllers; commits 06b8277..f4a3d1c (24) hold the base upgrade. A second batch (0a94429..20f4515) added: 2FA (email/SMS code on password login; OTP/Google bypass), dedicated POST /auth/change-password (admins can NOT set anyone's password anymore — fields stripped from all admin forms), /dashboard/settings UI, richer customer profile stats, DMS-style reports (preset period filter bars, recharts) and dashboard (trends, revenue, needs-attention strip, layout-faithful skeletons). 270 backend / 121 frontend tests. All local-only on main as of 2026-07-16 (user pushes after review).

**How to apply:** new optional env vars gate features: GOOGLE_CLIENT_ID / NEXT_PUBLIC_GOOGLE_CLIENT_ID (Google sign-in, 503/hidden when unset), SMTP_* (mail, log-only when unset), FROG_* (SMS OTP, log-only when unset), WEB_DISABLE_WORKERS (dedicated worker process), FRONTEND_URL (reset links). Legacy `Role.CUSTOMER` stays in the Prisma enum but no User rows use it. Money forms convert GHS decimals ×100 at the boundary.
