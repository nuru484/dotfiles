---
name: lfms-handoff-2026-09-29-r1
description: "START HERE for LFMS: S0 done and pushed 30 Sep 2026; next is S1 in lfms-api docs/todo/SESSIONS.md; lead builds directly on main"
metadata:
  type: project
---

State 30 Sep 2026 (all pushed):
- **S0 done:** wave 1 merged on main in lfms-api, lfms-web, lfms-site: FIC reports, screening, tipping-off guard, training register, practising status, critical deadline second check (lane A); uncleared client money and every upload scanned (lane B). Full gate green (API 4,042 tests, web 5,682 + build). Lead fixes at merge: override_clearance granted to partners only (not finance), scan state on lane A's attachments, period-close gate for accounts opened on the last day, demo reversal off the matter-rate scenario, goAML/PDF writer on the quarantine allowlist.
- **Next: S1** per lfms-api `docs/todo/SESSIONS.md` (46 sessions, 4-7 points each). The owner restarts after each session; each session ends gate green, pushed, box ticked, this memory updated.
- **How:** the lead builds directly on the main checkouts ([[lfms-build-on-main]]); at most one Sonnet helper for mechanical work. Dev mail stays logged ([[lfms-dev-mail-log]]). Scripted Playwright walk, one quiet full gate per session. Hooks: skill-set gate (load the side's skills + read engineering.md first), test-first commit gate (a new use case or screen needs a test naming it).
- **Owner findings in the O2 file:** O2.15 bank statement imports (added 30 Sep, session S18). Not yet added (owner said not yet): staff saved signatures stamped on firm documents, like AgriTrade.
- Reports: `docs/todo/reports/o3-compliance-report.md`, `o3-clearance-scan-report.md` (decisions listed there).

Traps: test PG 5433 via scripts/db/test-postgres.sh up; commit hook refuses AI attribution and "claude" in messages; merge commit subjects short (commitlint header limit); full gate ~40 min API+web, never edit the tree while it runs; FIC goAML format is FORMAT-VERIFY; clamav-freshclam is inactive on this machine (owner to `sudo systemctl enable --now clamav-freshclam`).
