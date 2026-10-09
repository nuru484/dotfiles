---
name: token-economy
description: Owner 9 Oct - save the plan limit: one session per milestone, screenshots of changed areas at 4 widths, routine work to one Sonnet helper, claude-mem on Gemini with its search hook off
metadata:
  type: feedback
---

The owner's limit was draining fast (9 Oct 2026); these are the standing fixes they approved.

- One session per milestone: push, update the handoff memory, and tell the owner it is a good point to close and start fresh. Never carry several milestones in one session.
- Screenshots: only the screens or areas that changed, but always at all four widths (1536, 768, 375, 344). No full sweeps of untouched screens. (Supersedes the "every width" breadth in [[check-ui-live]], keeps its four sizes.)
- Routine mechanical work (rerunning gates, fixing tests broken by a rename, syncing help, copy edits) may go to ONE Sonnet subagent with a full brief; judgement and design stay with the lead. Owner approved this 9 Oct; see [[delegate-to-sonnet-with-full-specs]].
- Read files by range (grep then sed), tail logs instead of dumping them, never re-read a file just edited.
- claude-mem: observer runs on Gemini (`CLAUDE_MEM_PROVIDER=gemini`) with its built-in quota fallback to Claude Haiku (`CLAUDE_MEM_QUOTA_FALLBACK_PROVIDER=claude`): on a Gemini quota error it cools Gemini down 30 min, uses Haiku, then probes Gemini and returns to it; its per-command memory search hook is off; start-of-session context trimmed to 10 observations / 3 sessions. Backup: `~/.claude-mem/settings.json.bak-2026-10-09`.
- lfms-web layout rules live in `docs/LAYOUT-RULES.md`, read only before UI work (the edit gate hook requires it on web edits); `lfms-web/CLAUDE.md` is now short.

**Why:** owner, 9 Oct: "my limit has been running fast down the lane ... diagnose and optimise it for good", then "make all the optimisations, except the screenshots ... it should check for all 4 sizes".

**How to apply:** at session start keep context lean; at each milestone end, push and suggest a fresh session.
