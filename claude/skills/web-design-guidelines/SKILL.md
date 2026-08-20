---
name: web-design-guidelines
description: >-
  Audit UI code against the Vercel Web Interface Guidelines (accessibility,
  focus, forms, semantics, UX details). Apply when asked to "review my UI",
  "check accessibility", "audit design", "review UX", or "check my site
  against best practices" - AND proactively as a self-check after completing
  or substantially modifying UI (pages, components, forms), before declaring
  frontend work done. This is the quality gate frontend-conventions and
  mobile-first-ui defer their a11y/UX audit to.
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
3. Check them against every rule in the guidelines
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
- No argument: review the UI files changed on the current branch
  (`git diff --name-only main...HEAD` filtered to `.tsx/.jsx/.css`), falling
  back to files changed in the working tree. Ask only when the diff is empty
  and the user gave no target.

## When running as a build self-check

After completing UI work (a page, a form, a component set), run this review
over the files just written and FIX what it finds before presenting the work,
rather than reporting the findings as a list. Report only what could not be
fixed and why.
