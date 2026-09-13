---
name: lfms-pause-for-ui-spec
description: After Phase 5 of the LFMS build plan completes, pause new phases until the owner writes a screenshot-based UI reference that every web agent must follow
metadata:
  type: project
---

On 2026-09-07 the owner asked that when Phase 5 (documents: search 5.9,
e-signature 5.10, retention 5.11 and their screens) is done, the build
pauses before Phase 6. They will produce a UI reference from screenshots
of the console: how a data table looks, how each kind of detail page
looks, how tables inside detail pages look, and so on, so agents stop
introducing their own UI patterns and follow one reference strictly.

**Why:** every milestone review found agents inventing layouts; the
CLAUDE.md principles were not enough on their own.

**How to apply:** do not dispatch Phase 6 until the reference exists;
once it does, put it in lfms-web (docs/design or CONVENTIONS.md) and cite
it in every web dispatch above the skills. See [[lfms-worktree-ui-pass]]
and [[lfms-ui-structure-principles]].
