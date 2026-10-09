---
name: lfms-roadmap-only-tracker
description: LFMS - lfms-api/docs/ROADMAP.md is the ONE plan; specs only after discussion in docs/specs (removed when ticked); docs/background = undiscussed inputs; lane reports reviewed then removed at merge; old docs at tag archive/plans-2026-10-05 (owner 5 Oct 2026)
metadata:
  type: feedback
---

`lfms-api/docs/ROADMAP.md` is the only progress tracker for Dangana (API, web, site). It lists Now, Next in order, Small fixes owed, Later, and Done (newest first). Both repos' CLAUDE.md/AGENTS.md point to it; TODO.md, docs/todo/SESSIONS.md and both HANDOVER.md files were deleted on 5 Oct 2026.

**Why:** owner, 5 Oct 2026: planning and replanning across five files (TODO.md, SESSIONS.md, HANDOVER.md, BUILD-PLAN, memory handoffs) left things disorganised; reporting looked unbuilt because nobody ticked it. "it should be straight forward to tell what's next, what's deferred for later... in that order".

**How to apply:** tick an item in the same commit that finishes it, with the day. Any change of order or scope is made in ROADMAP.md only, with a one-line reason. Specs stay in docs/todo/spec-*.md and BUILD-PLAN.md; decisions in PLAN.md. Session handoff memories only say where in the roadmap to resume plus traps, never their own task lists. Codex lane ticks its box in ROADMAP.md (BRIEF.md, run.sh updated).

**Docs layout (owner, 5 Oct 2026):** `docs/specs/` holds specs of AGREED open work only (written after the owner discussion, deleted when the item is ticked; history keeps them). `docs/background/` holds inputs for discussions still to come (tenancy design + owner brief, features per firm, O2 owner review, O3 audit, live-test follow-ups; site plan in lfms-site): never built as written; tenancy is reviewed with the owner and every disagreement settled before any spec. A lane's report lives on its branch for the lead's review; the lead writes decisions into PLAN.md, ticks the roadmap and removes the report in the merge. Everything finished before 5 Oct (docs/todo specs, reports, refs, web design files, TODO/SESSIONS/HANDOVER) is at git tag `archive/plans-2026-10-05` in each repo; `docs/ARCHIVE.md` explains. graphify-out is local only (gitignored). Codex does not move on to S15 until it is discussed.


**Lane assignment (owner, 5 Oct 2026):** ROADMAP "Later" is split into "Free now" (no dependency on the main line either way; any lane may take one, after the owner discussion) and "Waits for a main-line item" (each names the item; NEVER assigned to Codex, another agent or the lead before that item is merged and ticked). Owner accepted the main line 1-11 order as is, with the depth sessions after item 11 unless a lane takes a Free-now one earlier.
