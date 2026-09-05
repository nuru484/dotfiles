---
name: codebase-guide-per-repo
description: "User wants deep codebase studies persisted as a gitignored \"what and how\" orientation guide in the repo (.claude/codebase-guide.md + CLAUDE.local.md pointer), not just a chat/artifact report"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 81cc56d0-82f0-4d52-b65c-ee5c74b7186b
  modified: 2026-08-15T15:52:07.002Z
---

After a deep study of a repo, write the findings into the repo as an
orientation guide — `.claude/codebase-guide.md` (what the system is, how each
key flow works, conventions, data model, known bugs/gotchas, refactor
targets, recipes) plus a short `CLAUDE.local.md` at the repo root pointing to
it — and add both to `.gitignore`. Done for `aesthetics-suites` on 2026-08-15.

**Why:** the user wants future Claude Code sessions to load a detailed
understanding of the project immediately instead of re-exploring hundreds of
files each time; a report-style artifact on claude.ai doesn't serve that.

**How to apply:** when asked to "study"/"understand" a codebase, deliver the
report AND the in-repo guide (written as "what and how", not graded
findings). Keep the guide's known-gaps section current when fixing items.
Related: [[user-permission-bypass-mode]]
