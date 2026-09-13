---
name: lfms-law-is-data
description: On LFMS every legal, tax or regulatory rule is firm-configurable data on a settings screen, never logic in code; LEGAL-VERIFY items resolve to confirmable defaults
metadata:
  type: feedback
---

On 2026-09-07 the owner settled how the design's LEGAL-VERIFY and OPEN
items are handled: the system is built so the firm's own lawyer or
administrator configures them, and the developer never bakes the answer
into code. That covers which document classes may be e-signed, limitation
periods and deadline counting conventions, client account rules, tax
rates and disbursement treatments, VAT invoice content, GRA fiscalisation
endpoint and credentials, AML thresholds and block-versus-warn, and
retention periods. The code seeds a cited default; a settings screen lets
the firm change it; the change is audited.

**Why:** the owner said plainly that lawyers should determine these, not
the developer, and asked for the plan to say so. It also removes the
"needs external input" blockers from the build: the answers gate a firm's
launch, not the code.

**How to apply:** recorded in lfms-api/CLAUDE.md, PLAN.md (domain summary)
and docs/BUILD-PLAN.md definition of done item 13, and in
lfms-web/CLAUDE.md. Any milestone that implements such a rule must ship
the settings screen for it in the same milestone. See
[[lfms-worktree-ui-pass]] and [[milestone-start-grounding]].
