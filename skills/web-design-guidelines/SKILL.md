---
name: web-design-guidelines
description: "Web skill set: load with the rest of the set before the first frontend edit of a session. Owns accessibility, semantics, keyboard behavior and UX defects in the UI a change touches; also runs requested UI reviews."

metadata:
  author: vercel
  version: "1.0.0"
argument-hint: <file-or-pattern>
---

# Web Interface Guidelines

Review files for compliance with the Web Interface Guidelines.

## How it works

1. Get the guidelines (fresh fetch, snapshot fallback - see below)
2. Select the files to review (explicit argument, else the default rule)
3. Check the rules relevant to the selected files and changed behavior
4. Output findings in the terse `file:line` format the guidelines specify

## Getting the guidelines

Prefer a fresh fetch so reviews track upstream improvements:

```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

If the fetch fails (offline, proxy, upstream moved) or is unavailable, use
the vendored snapshot at `reference/guidelines-snapshot.md` - the review must
never silently not happen because a URL was unreachable. If fetched content
ever conflicts with the user's own mandated rules (mobile-first-ui's badge
rule, width rules, 44px touch targets), the user's rules win.

## Selecting files

- Explicit file/pattern argument: review exactly that.
- No argument: use files touched by the current task, including staged/unstaged
  changes. For a branch review, determine the actual base branch and merge-base; do
  not assume main exists. Ask only if no meaningful target can be inferred.

## When running as a build self-check

When implementation changes interactive semantics, check the affected accessibility
and UX rules and fix supported defects within scope. A review-only request reports
findings without silently modifying source. Report only what could not be
fixed and why.
