---
name: lfms-referrals-10b
description: "LFMS referral engine rebuild is Phase 10B, after 10A R4 and before Phase 11; referral rewards go to lawyers only (owner, 2026-09-29)"
metadata:
  node_type: memory
  type: project
  originSessionId: 5e61fdba-c5a5-4eb8-97de-16356b1e1890
  modified: 2026-09-29T16:01:14.618Z
---

Owner found the referral engine thin on 2026-09-29 (sources list + referrer party on the matter only). Decided: rebuild as **Phase 10B Origination and client acquisition** (origination/responsible/working credit with splits and approval, sources and referrers enquiry→client→matter, codes, fee sharing with outside lawyers, compensation reads, acquisition reports) in lfms-api `docs/BUILD-PLAN.md`, scheduled after 10A R4, before Phase 11 payments. **Rewards go only to lawyers** (firm's own lawyers as staff incentives; outside lawyers where fee sharing between lawyers is allowed), never clients or other non-lawyers; the L.I. 2423 restriction is a firm setting with a cited default, marked LEGAL-VERIFY.

**Why:** Ghana's conduct rules restrict paying non-lawyers for introducing clients; staff referrers need R2's people records; rewards are paid from collected fees.

**How to apply:** do not start Phase 11 before 10B is done; the eligibility rule is enforced in use case and database, not only UI. Related: [[lfms-discuss-before-payments]], [[enterprise-complete-linked-entities]].
