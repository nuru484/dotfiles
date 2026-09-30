---
name: lfms-no-firm-data
description: "No firm has data in LFMS (2026-09-29); migrations may drop/rebuild, demo data is disposable: wipe and reseed, fold unpushed migrations"
metadata:
  node_type: memory
  type: project
  originSessionId: 5087a1d5-35c4-47a4-8722-4e5c09cfd52b
  modified: 2026-09-29T05:04:38.027Z
---

Owner confirmed 2026-09-29: no firm keeps any data in LFMS yet, so schema changes may drop columns, re-point postings and rewrite the demo seed without preserving history.

**Why:** pre-launch; only the demo seed exists.

**How to apply:** prefer the clean model over compatibility shims in migrations until the owner says a firm is live. Re-check this before any destructive migration after launch. Related: [[enterprise-complete-linked-entities]], [[lfms-deploy-migrates]].

**Demo data is disposable (owner, 2026-09-29):** never spend effort preserving demo or dev data through a change. Wipe and reseed (`migrate reset` + `seed` + `seed:demo`) when that is faster; fold an unpushed milestone's migrations into one rather than stacking fix-up migrations.
