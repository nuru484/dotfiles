---
name: fix-the-class-not-the-instance
description: "When the user reports a UI or code fault, sweep the whole system for the same fault class and fix every instance rather than only the one named"
metadata:
  node_type: memory
  type: feedback
---

When the user points at a defect, they are naming an example, not the scope.
Fix the class: sweep every screen or module for the same fault and correct all
of it, then record the rule where future work will read it. Do not wait to be
told about the second and third instance.

On a large surface, dispatch a dedicated agent whose job is the sweep, with
the recorded rules as its checklist, working in a worktree so it does not
collide with feature work.

**Why:** the user said plainly on 2026-09-07 that they should not have to
mention each occurrence one by one, after several rounds of pointing at the
same fault on different pages.

**How to apply:** on the first report of a fault, write the rule into the
repo's own CLAUDE.md so every agent sees it, then sweep. See
[[lfms-layout-corrections]] for the LFMS rule set this came from.
