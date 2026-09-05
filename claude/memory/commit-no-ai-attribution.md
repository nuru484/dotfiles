---
name: commit-no-ai-attribution
description: "How the user wants git commits authored: no AI attribution; on LFMS commit small chunks as each piece goes green without asking; push only when asked"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 50b9d249-f346-4da2-a8d4-9e62d0d44e79
  modified: 2026-09-05T10:01:16.800Z
---

The user does NOT want any AI/tooling attribution in git history. Never add a `Co-Authored-By` trailer, "Generated with Claude", or any mention of Claude / Anthropic / AI in commit messages OR PR bodies. This overrides the harness default that appends a Claude co-author line. The LFMS repos enforce it with a commit-msg hook that rejects those words, and commitlint caps the header at 90 chars.

**Commit cadence (updated 2026-09-05):** on lfms-api and lfms-web the user said "commit often, incrementally, small small in chunks, as features come to life, don't wait to commit one big batch". Commit each feature or fix as soon as its tests and lint are green, without asking first. This came after a UI experiment they rejected could not be rolled back with one git command because nothing had been committed. Other repos: check `git log` and ask if unsure. Push still only on request.

Match the repo's existing commit style (`feat(scope): sentence` on LFMS); stage only relevant files and surface unrelated changes rather than bundling them. The LFMS pre-commit hook stashes unstaged work and runs typecheck (about a minute), so never edit files while a commit runs.

**Why:** the user owns the work; tooling credit doesn't belong in their history. Small commits give them a cheap rollback point for each experiment.

**How to apply:** write the message in the user's voice with zero AI references, commit at each green checkpoint on LFMS, and push only on request. See the [[git-workflow]] skill and [[parallel-agents-both-repos]].
