---
name: lfms-fixes-2026-09-29
description: "LFMS lessons from the roles, courts and list fixes — cumulative roles, nested scopes, singleton limits in the DB, two-column records rail-first on phones, dialogs per kind"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 7239d7a3-327e-4e89-aeb1-96ea371ea276
  modified: 2026-09-29T03:59:43.445Z
---

Lessons the owner's 28-29 September 2026 fixes taught; follow them so the
faults do not come back.

- **Roles are ranked and cumulative.** One role per person; a role does
  the work of the junior roles on its own line only (Partner > Associate >
  Trainee > Paralegal; Accountant > Bookkeeper; Firm admin > Secretary;
  the managing partner over all four heads). Never let a fee-earner line
  inherit a finance line or reception: that broke segregation of duties
  (a partner posting journals, approving bills not theirs).
- **Scopes nest**: own < supervised < practice_area < all, in every place
  reach is judged (authorize, the matter reach filters, time and task
  reach). A wider merged grant must reach everything a narrower one did.
- **A singleton is enforced in the database**, not only in the use case
  (the managing partner via a holder-limit trigger; one Supreme Court via
  a partial unique index). Seeds and scripts must pass the same rule; a
  migration sets a limit only where existing data already keeps it.
- **Two-column records** use `RecordLayout width="wide"` with the facts
  in the rail; on a phone the rail reads first (source order too).
- **Two kinds of record get two dialogs** (a class of court and a court),
  never one form whose meaning flips on a blank field.
- **Raw SQL** reads another module's table only through its facade and
  always filters `deleted_at`; the ownership and soft-delete guards catch
  it.

**Why:** each was a fault the owner found or the gates caught on 28-29
September 2026.
**How to apply:** check these before building any role, scope, singleton,
record page or dialog. Related: [[every-list-searchable]],
[[fix-the-class-not-the-instance]].
