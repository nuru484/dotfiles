---
name: codex-lane-owns-sessions
description: "LFMS S18, S12, S20, S21, S22 belong to the Codex lane: never build them on main, whatever the plan says, until the owner explicitly hands them back; review every finished lane session to the lead's own standard"
metadata:
  node_type: memory
  type: feedback
  originSessionId: fd6045f7-4a8c-47a2-ae49-5befc426edac
  modified: 2026-09-30T09:37:33.116Z
---

Sessions S18 (bank statement imports), S12 (GRA E-VAT), S20 (SSO), S21 and S22 (mailbox) are built by Codex in `/home/nurudeen/repos/worktrees/s18/`. A Claude session never builds, starts, or "helps along" any of them on main, even when the roadmap reaches them, even when the lane is paused or halted, until the owner says in so many words that the Codex weekly limit is spent and hands them back. docs/ROADMAP.md marks them `[CODEX LANE]`. Skip over them to the next unmarked session.

**Why:** owner, 30 Sep 2026: "ensure that next sessions knows and understand codex is handling some of the works, and so it doesn't pick it up again, no matter what, until I run out of the weekly limit and tell it explicitly."

**How to apply:**
- Codex was given every decision up front: `lane/<S>.md` (the work, decided), `lane/RULES.md` (skills from `~/.agents/skills`, API and web patterns, styling, code voice), inlined into `../BRIEF.md`. When a spec is thin, the lead thickens it before the lane reaches it; never let Codex design.
- **Lane loop (owner, 30 Sep 2026; survives Claude restarts, all state on disk):** each session runs as two fresh Codex runs, API then web (`lane/run.sh`), then status.txt says `<S> AWAITING REVIEW` and the lane stops. At the start of every Claude session: `tail lane/status.txt`. If AWAITING REVIEW: review (below), merge the branch into main in each repo (migrations in timestamp order; PLAN.md by hand, tick the item in docs/ROADMAP.md (the branch may still tick the deleted SESSIONS.md: keep it deleted)), gates one repo at a time, push, then `touch lane/state/<S>.merged` and relaunch: `cd /home/nurudeen/repos/worktrees/s18/lane && setsid nohup ./run.sh >> lane.out 2>&1 < /dev/null &`. The next session branches from main. PAUSED (usage limit): relaunch the same command after the reset. STOPPED: read `logs/<S>.<phase>.log`, fix the cause, relaunch. S18 began before the split as one run (`ids/S18`, `logs/S18.log`); `watch-s18.sh` hands it to run.sh when it exits. `run.v1.sh` is the old stacked runner, kept for reference only.
- When a session's report lands (AWAITING REVIEW in status.txt), review it as if I had built it: diff each worktree's branch against main, check every line of `lane/<S>.md` and `lane/RULES.md`, run its targeted tests, walk its screens at the five widths with max-length data. Small misses: fix on the branch myself. Real gaps: resume Codex with the list (`codex exec resume <id> "<fix list>"`, id in `lane/ids/<S>`, only when not running). Merge only when it is how I would have built it.
- Pause and resume: as in the loop above (PAUSED: relaunch run.sh after the reset). Related: [[enterprise-workflow-logic-first]], [[no-subagents-by-default]] (the lane is the owner's explicit exception).
