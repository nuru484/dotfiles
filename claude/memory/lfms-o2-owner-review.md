---
name: lfms-o2-owner-review
description: "LFMS owner's depth-not-breadth review backlog (2026-09-29) lives in lfms-api docs/todo/spec-o2-owner-review.md, TODO item O2; append new findings there"
metadata:
  type: project
---

Owner is walking LFMS and listing broad-but-shallow features. Backlog: `lfms-api/docs/todo/spec-o2-owner-review.md` (placed in docs/ROADMAP.md: Small fixes owed and Later): departments, document folders + folder access, self-service access requests, person page with matters/rates/staff no/office/department, virus-scan every upload, view-before-download for every file. Planned elsewhere: Phase 10B origination, 10C SMS by destination, Phase 11 payment provider facts.

**Why:** owner wants enterprise depth matching how law firms work, not prototypes.

**How to apply:** check each new owner complaint against code first, record finding + requirement in that file, then build via fully-specified agent briefs ([[delegate-to-sonnet-with-full-specs]]) as agent slots free up; review and re-spec anything not done my way.

**Hold on dispatch (owner, 2026-09-29 evening):** when the running agents (R1 web, R2a API) finish, review and merge their work but give them no new work; the owner wants every flagged fix written into the O2 backlog first, thorough and complete to legal-firm workflows. For every owner finding, say whether the owner's way is right, wrong or incomplete, and give the complete industry workflow. Template editing decision: Word check-out/check-in now, in-browser editor later.

**O3 system audit (2026-09-29):** my own module-by-module audit is in `lfms-api/docs/todo/spec-o3-system-audit.md` (TODO O3), with a top-20 risk ranking across O2 and O3. Planned phases 11–17 are not gaps.

**Binding build rules:** both backlog files open with "How every item in this file is built (binding)" (12 points: records, enforcement points by operation id, law as data, permissions and second person, connections/back-refs, notices and escalation, audit, screens from PATTERNS walked at 5 widths, reports, test-first incl. refusals/races/idempotency, demo/help/docs, benchmark). Every brief must satisfy all 12; the owner will not accept bare-minimum builds.
