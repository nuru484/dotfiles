---
name: khadys-kitchen-role-rules
description: "Khady's Kitchen role hierarchy — assignment ranks and exactly what STAFF is blocked from"
metadata: 
  node_type: memory
  type: project
  originSessionId: ff54852e-21ad-4321-972c-2e57893ed0ce
---

Khady's Kitchen (repos/khadys-kitchen-backend + -frontend) role rules, decided 2026-07-07:

- Role assignment: SUPER_ADMIN grants up to own rank (can mint other super admins); ADMIN grants strictly below (STAFF only). Enforced in `user.service.ts` `canAssignRole`.
- STAFF has read/create/update access to the whole admin console (`requireStaff` base guard) but is blocked from: all deletes, user management (`/admin/users`), refunds/payment reversals, order cancel, application rejection (conditional `requireAdminForRejection` middleware), and site-settings edits. Publish/unpublish and availability toggles ARE allowed for staff.
- Frontend mirrors this via `useAuthRole().isAdmin` gating + `orderActionsFor`/`applicationStatusActionsFor` helpers; Team nav item is `adminOnly`.
- Test coverage: `test/integration/staff-access.test.ts`.

**Why:** the owner wants staff to work the counter/school without being able to destroy records or move money.
**How to apply:** any new admin route defaults to `requireStaff`; add `requireAdmin` for destructive/money/visibility-of-users operations, and mirror the gate in the UI.
