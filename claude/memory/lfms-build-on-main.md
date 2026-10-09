---
name: lfms-build-on-main
description: "From 30 Sep 2026 the lead builds LFMS directly on the main checkouts, and the one Sonnet helper works there too; no worktrees"
metadata:
  type: feedback
---

Owner, 30 Sep 2026: "when you are to be doing it yourself, just do it on the main repo, and ... for the sonnet small ones to also go on ... instead of the worktrees."

**Why:** worktrees cost setup (hard-linked node_modules, env copies, schema-to-schema migrations, contract syncing into the worktree, merges) and tokens; with the lead building directly there is no parallel lane to isolate.

**How to apply:** edit lfms-api, lfms-web and lfms-site main checkouts directly, commit green chunks there; the Sonnet helper edits the same checkout on files the lead is not touching at that moment. `contracts:sync` goes straight to lfms-web. Supersedes the worktree parts of [[lfms-worktree-ui-pass]] and [[delegate-to-sonnet-with-full-specs]]. See [[lfms-handoff-2026-09-29-r1]].

**Exception (30 Sep, owner):** the Codex lane builds independent sessions in its own worktrees under `/home/nurudeen/repos/worktrees/s18/`; see [[lfms-handoff-2026-09-29-r1]].
