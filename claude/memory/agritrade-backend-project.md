---
name: agritrade-backend-project
description: "AgriTrade backend at ~/repos/agritrade-backend — Mr. Hassan's trading/land/farm-investment system; khadys-kitchen-backend is the pattern reference"
metadata: 
  node_type: memory
  type: project
  originSessionId: d4c8baf5-1cd7-440f-8139-4994598b0070
  modified: 2026-07-24T23:30:24.130Z
---

`~/repos/agritrade-backend` is the Express/TS/Prisma backend for Mr. Hassan's
(Tamale) agricultural trading + land sales + farm investment system. Built
milestone-by-milestone from an approved full-system design doc the user keeps
(ledger-based stock/float, lot costing, Frog/Wigal SMS).

**Status (2026-07-24):** system is FEATURE-COMPLETE for launch. M1-M12
substantially built and tested (registry, purchases/floats, agent app, stock,
approvals, sales+manual payments, shipments/costing, land, farm, notifications,
reporting, public site). Remaining is deployment/hardening (M13). **Online
payments (Hubtel, M7) were DROPPED by client decision** - manual cash/MoMo/bank
payments are first-class; the public /pay page and gateway are not built.
This session added: sidebar → collapsible grouped dropdowns with Land & Farm as
SEPARATE groups; navbar search box REMOVED (so the old "live ?q= search" note
below is obsolete); dashboard rebuilt with **recharts** charts + a date-range
filter (new report endpoints: /period-summary, /cashflow, /volume, /activity,
/debtors JSON + a report-range.ts trend/bucket engine); reports page upgraded
with charts; and a NEW **land-acquisition (land-buying) module** - models
LandSeller (directory), LandAcquisition (NEGOTIATING→AGREED→COMPLETED, which
produces a LandPlot; reference becomes the plot ref, agreedCost→purchaseCost)
and LandAcquisitionPayment (flexible ledger, manual methods only); routes under
/admin/land/{sellers,acquisitions}. Frontend charts use recharts ^3.10 (dms
pattern); reusable kit at frontend src/components/admin/dashboard/chart-kit.tsx.

**GOTCHA (WSL):** `tsx --watch` (backend dev, `npm run dev`) does NOT reliably
reload NEWLY-ADDED route/module files - it serves the pre-existing route table
and new endpoints 404 while others work. After adding a new route file, RESTART
the backend. (Caused the farm-routes 404 this session; editing existing files
reloads fine.) Verify a route is mounted with `curl -o /dev/null -w "%{http_code}"
localhost:4060/api/v1/<path>` → 401 = mounted, 404 = stale server.
Playwright rig: MCP `chrome` channel isn't installed (needs sudo); drive the
bundled chromium directly via `~/.pw-check/node_modules/playwright-core` +
`~/.cache/ms-playwright/chromium-1228/chrome-linux64/chrome` (see scratchpad
shot*.mjs). Login: SUPER_ADMIN_EMAIL/PASSWORD from backend .env; app on :3000,
API on :4060; seed data via authenticated `fetch(..., {credentials:"include"})`.

**Status (2026-07-12):** M1 foundation + full auth done (57 tests green,
committed on main, no remote yet). Auth includes two-stage brute-force defence
(5 fails → 15-min re-arming lock, 10 → hard block; unblock via
`PATCH /admin/users/:id/unblock` or completed email password reset), audit-log
wiring for all security events, lastLoginAt/Ip stamping, blocked-account alert
emails, email-change confirmation (pendingEmail + mailed link), refresh-token
rotation with reuse detection (RefreshSession rows, replay revokes all
sessions), and 8 single-use 2FA recovery codes (login fallback + regenerate).
2FA is opt-in for ALL roles by explicit user decision — do not make it
mandatory for super admins. 66 tests green. Next: M2 core registry (users
admin, warehouses, commodities, suppliers, buyers), then purchases/floats.

**User management (done 2026-07-12):** full super-admin surface at
/admin/users — create/list/update/role/deactivate/activate(clears block)/
unblock/2FA-reset/send-password-reset/soft-delete, last-super-admin guard.

**Frontend:** `~/repos/agritrade-frontend` (brand renamed by user to **DB
Plus**, hint cookie `dbplus.auth.hint`; Next 16 + RTK Query) fully wired:
Mutex silent-refresh api-slice, proxy /admin gate + RequireAuth,
login/2FA(+recovery)/forgot/reset, profile page (edit form, multipart photo
upload w/ Cloudinary server-side + remove, collapsed password form,
confirm modals, password visibility toggles), navbar account menu (dms
pattern) + live ?q= search + inert bell, and a live /admin/users module
(list/create/detail with all account actions). Backend brand aligned to DB Plus
(COMPANY_NAME, mail defaults, EJS template). Console has dms-grade tables — now
fully SERVER-driven for users (debounced search/facets/pagination hit
GET /admin/users; keep-last-page + dim while fetching), ConsoleFilterBar
(khadys mobile-collapse pattern), selection + bulk delete, Actions column,
role-change modal, photo preview-before-save (PhotoManager, shared with
admin user detail — admins manage users' photos; backend PATCH
/admin/users/:id accepts multipart), banner-style identity cards, login page
bounces authed users, SidebarTrigger collapse, Settings under avatar menu,
use-table-query hook (URL sync + session memory, from khadys), audit-log
module live (GET /admin/audit-logs + frontend register).
VERIFY UI VISUALLY: playwright rig in scratchpad (chromium cached) —
screenshot fold/phone/tablet/desktop before claiming done; user was rightly
unhappy when this was skipped. 50 seed users (seed-user-N@dbplus.local /
Password123!) in dev DB for pagination testing.

**Conventions:** replicate `~/repos/khadys-kitchen-backend` patterns (the
newest reference; dms/website backends are older). Roles are
SUPER_ADMIN/STAFF/AGENT (+ `canApprove`, `financialVisibility` flags). TypeScript pinned to 6.0.x
(typescript-eslint peer cap `<6.1.0`); ESLint 10, Vitest 4 (`fileParallelism:
false` replaces the old `poolOptions.forks.singleFork`), nodemailer 9, EJS 6.
Local dev DB: Postgres over unix socket
(`postgresql://nuru@localhost/agritrade?host=/var/run/postgresql`), tests
auto-create `agritrade_test`.


**DB Plus design system (frontend):** ONE system, defined by /style-guide
(the law) and applied at component roots. Console tokens alias the brand
palette (console=forest, console-page=surface husk, console-red=error).
NO slate utilities in admin — warm scale: ink/soil/surface-alt/paper.
Buttons: square rounded-[2px], font-bold, hard block shadows that press in
on hover; Button variant "harvest" = client primary (gold, ink text);
outline = 2.5px forest. Inputs = enquiry-form document field (bg-paper,
1.5px soil/35 border, leaf focus glow, aria-invalid:border-error) via
adminInputClass + base Input. Cards = AdminCard filed document (square,
soil border, shadow-doc-sm). Dialogs = paper docs, dotted footer band.
Labels = stencil harvest-deep micro-caps. Toolbars = stock-register boxed
controls (h-8, square, paper). Table empty states = EmptyState
variant="plain" (no container). Pagination = ledger idiom (mono zero-padded
readout + progress track). Toolbar tiers: lg+ one row, md-lg full search +
<=4-col grid, <md 2-col Filters toggle panel. New list modules must follow this idiom, not
generic shadcn boxes.
Dropdowns/select popovers: ONE skin app-wide, baked into ui/dropdown-menu.tsx
and ui/select.tsx — the website services plate (square, 1.5px soil/50 top
hairline, 3px forest bottom rule, bg-surface, deep shadow, dotted soil rules
between rows, harvest/12 focus tint, harvest-deep micro-cap labels). Don't
re-add borders/padding overrides on Content in consumers.
