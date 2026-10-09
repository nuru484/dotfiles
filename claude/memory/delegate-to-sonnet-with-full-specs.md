---
name: delegate-to-sonnet-with-full-specs
description: "Owner, 30 Sep (S2 web): split each web/API session: lead builds the judgement-heavy part, ONE Sonnet helper builds the pattern-copy part from a full written spec in the scratchpad (files, examples to copy, every decision, guards to run, no commits); lead reviews its diff"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5e61fdba-c5a5-4eb8-97de-16356b1e1890
  modified: 2026-09-29T15:16:52.297Z
---

Owner, 2026-09-29 (LFMS R1/R2): "use sub agents now, sonnet 5.5, very very detailed descriptions... it shouldn't be the one deciding, you have to decide everything, plan it and hand it over to execute and you will check its work too when it's done." Up to two agents where two is faster. Later the same day: "Use opus for the sub agents, only use sonnet for short fixes." Do not hand the brief to the owner to run elsewhere; launch the agents myself.

**Why:** Sonnet executes well but does not reason as broadly; leaving design choices to it produces drift. Parallel agents were also the reason earlier milestones went faster than single-session retrofit work.

**How to apply:** only once the owner has opted in (default stays [[no-subagents-by-default]]). Brief = exact files, schemas, endpoints, field names, copy, component to copy from, tests to write, commands to run, what not to touch, and the done check. Give each agent its own worktree/branch; never two agents running `next dev` at once (WSL OOM, see [[khadys-dev-testing-notes]]). Review the diff and re-run its checks before merging.

**Update 30 Sep 2026 (owner):** asked for exactly this again to save tokens, since Sonnet and Codex drift without decisions made for them. Worked on S2 web: the helper built Settings → Intake from `scratchpad/s2-settings-spec.md` while the lead built the workspace; nav, descriptions and shared files were done by the lead first so the two never touched the same file. The spec must name the guard tests (placeholders, dialog-width, permission-guard, record-links) because they are what a helper misses.
