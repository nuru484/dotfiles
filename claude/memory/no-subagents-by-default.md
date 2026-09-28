---
name: no-subagents-by-default
description: "Never use subagents unless the owner explicitly asks in that request; an unnumbered ask means exactly one subagent plus the main session"
metadata:
  type: feedback
---

Do all work in the main session, leanly. No Agent calls, forks or workflows
unless the owner explicitly asks for subagents in that request; if they ask
without a number, spawn exactly one. Also written into the global CLAUDE.md
(dotfiles), which is the durable copy.

**Why:** 2026-09-27 the owner told me to stop fanning work out to agents
after I split an LFMS review across two; this replaces the 2026-09-05
"build API and web with parallel agents" rule, now deleted.

**How to apply:** on LFMS work the API and web in sequence yourself: API
schemas first, `npm run contracts:sync`, then web. Load the house skills
per [[milestone-start-grounding]] for your own edits.
