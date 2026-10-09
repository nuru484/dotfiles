---
name: one-heavy-check-at-a-time
description: Heavy checks (lint, full suite, whole tsc, build, walk) go through ~/repos/heavy-check, ONE slot shared with Codex (owner 5 Oct); API suite with 6 workers when alone; targeted tests one at a time, npm run typecheck not bare tsc
metadata:
  type: feedback
---

Run every heavy check, mine or the Codex lane's, through `/home/nurudeen/repos/heavy-check <cmd>`. Heavy means `eslint .`, a full test suite, a whole-repo `tsc`, a build, or a walk. The script has two slots (`HEAVY_SLOTS`): a check starts at once while a slot is free and waits only when both are busy. Slot 1 is `~/repos/.heavy-check.lock`, so a plain `flock` on that file still counts. Targeted tests need no slot. The lane's RULES.md says the same.

**Why:** on 2 Oct 2026 an unlimited mix ran the 32GB machine out of memory and killed both lanes. A single lock that followed made everything queue for too long, and the owner said "you decide how many can run at a time". Each heavy check costs about 6-8GB: typed lint and tsc build the whole program, and the API suite runs 7 workers each loading the app.

**How to apply:** prefix heavy commands with `~/repos/heavy-check`. Raise `HEAVY_SLOTS` only if free memory shows room. Related: [[speed-without-subagents]], [[codex-lane-owns-sessions]].

4 Oct 2026: the machine ran out of memory again; owner said test leaner, run in parallel only what 32GB allows. Run targeted tests one at a time (never alongside a heavy check), stop stale dev servers before a heavy check, and use the package scripts (`npm run typecheck`/`lint`), not bare `npx tsc`, which OOMs at Node's default heap.

5 Oct 2026 (owner): tests always run locally before a push (no relying on CI for that), with more workers, but Codex, the web and the API must not run heavy checks together. heavy-check now defaults to ONE slot, so a heavy check waits for any other; the API full suite runs with `TEST_WORKER_COUNT=6` when it has the machine. Lane RULES.md updated to one at a time.

