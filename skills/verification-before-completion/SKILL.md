---
name: verification-before-completion
description: "Match completion claims to evidence for the changed behavior, checks, and release status. Use when reporting implementation results; re-use valid evidence for unchanged code rather than rerunning checks for each message."
---

# Verification before completion

Choose evidence that supports the actual claim. A typecheck proves typechecking,
not runtime behavior; a targeted test proves its covered cases, not the full suite.

1. Match the changed requirements to checks or inspectable artifacts.
2. Run relevant checks using project commands. Read exit status and failure details.
3. Re-run only when a relevant change or environmental difference invalidates the
   evidence. A new message does not invalidate a passing result.
4. Inspect the final diff for omissions, unrelated changes, and accidental secrets.
5. State the result with its practical limits and any remaining required work.

For a bug, reproduce the original symptom, preferably with a regression test;
confirm failure before the fix and success after it. Do not destructively revert
unrelated work merely to demonstrate a red-green cycle.

For delegated work, inspect the resulting artifacts and the reported check evidence.
Do not accept a bare success assertion or rerun everything solely because an agent
performed it. For a release, use release-deploy's environment and smoke evidence.

Pre-existing failures remain separate from new regressions. Fix blockers within
scope; do not conceal failures or expand the assignment to unrelated repairs.
Visual verification follows the user's review workflow. An unavailable browser or
service is an unverified item, not a passing check and not a reason to block useful
independent work.

Report briefly: what changed, checks and their result, and material limitations.
Do not claim end-to-end or production verification from static inspection alone.
