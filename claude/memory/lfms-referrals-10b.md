---
name: lfms-referrals-10b
description: "LFMS Phase 10B referrals follow real firm practice (Clio/Aderant/Elite + L.I. 2423): origination credit feeds comp review, outside lawyers by consented fee share, non-lawyers thanked (gift register, capped) never paid"
metadata:
  type: project
---

The referral rebuild is **Phase 10B Origination and client acquisition**. It comes after 10A R4 and before Phase 11. The spec is in lfms-api `docs/BUILD-PLAN.md` Phase 10B (rewritten 2 Oct 2026).

The model, benchmarked on Clio Manage/Grow, Aderant, Elite 3E and L.I. 2423:
- The firm's own lawyers are never paid per client. They hold origination credit (splits, approval), which is read at partner compensation and annual review. An optional associate business-development bonus formula is off by default and computed only at review.
- Outside lawyers are paid by fee sharing with the client's written consent.
- Clients and other non-lawyers are recorded as referrers and thanked: a letter, a task, a nominal gift in a gift register with firm caps. They are never paid. Reciprocal referral relationships are recorded and the client is told.
- The settings carry the rule with its citation (LEGAL-VERIFY). No setting allows paying a non-lawyer.

**Why:** the owner, 2 Oct 2026: "it's not about what I wrote, it's about what's being done in real law firms ... enterprise systems like Clio ... whiles still meeting the ghanaian legal context". Their earlier ask, a reward engine for non-lawyers, was rolled back because the industry doesn't do it and Ghana's rules forbid it.

**How to apply:** build 10B to this, and do not start Phase 11 before 10B. In general, benchmark the owner's domain suggestions against industry practice and say where they differ, rather than writing them in verbatim (see [[enterprise-workflow-logic-first]]).
