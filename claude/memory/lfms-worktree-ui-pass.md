---
name: lfms-worktree-ui-pass
description: "On LFMS the main checkouts stay on main for the owner's UI passes; every milestone agent works in a git worktree on a feature branch and merges back"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 112e9db3-8861-4672-960a-2e2c502b1a65
  modified: 2026-09-07T14:06:28.527Z
---

From 2026-09-07 the owner reviews the LFMS console on their dev server,
which watches the main checkout of ~/repos/lfms-web, and sends UI faults
to be fixed on main while the build-plan milestones run on branches.
So: the main checkouts of lfms-api and lfms-web are never switched to a
branch. Each milestone (worked in the main session, see [[no-subagents-by-default]]) creates its own worktree under
`.claude/worktrees/<name>` on `feature/<name>`, symlinks node_modules,
copies .env (API: also `npx prisma generate`), runs its gate there, merges
main into its branch before merging back, then merges to main from the
main checkout with `--no-ff`, pushes, and removes the worktree. The API
test databases are named from the checkout path, so worktree suites do
not collide. Contracts sync from an API worktree uses
`CONTRACTS_TARGET=/home/nurudeen/repos/lfms-web/src/contracts` and the
copy is committed on web main right away (with any new audit entity
labels in `src/types/audit.types.ts`, which the typecheck demands).

**Why:** the owner asked for UI passes on main so they see fixes land
without waiting for a milestone, and for the phases not to interfere with
that work.

**How to apply:** the grounding blocks in the session scratchpad carry
these steps; keep them in every dispatch. A UI rule fixed on main goes into
lfms-web/CLAUDE.md or docs/CONVENTIONS.md as well, and each agent re-reads
those before merging so new screens follow it. See
[[no-subagents-by-default]] and [[lfms-ui-structure-principles]].
