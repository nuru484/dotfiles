---
name: git-workflow
description: >-
  The user's git and pull-request authoring conventions — commit message style,
  branch naming, when to commit/push, and PR descriptions. Apply AUTOMATICALLY
  and ALWAYS before committing, pushing, or opening a PR in any repo. Use whenever
  the task involves git history or proposing changes for review. This governs how
  commits and PRs are authored (not code review, which the review skill owns).
---

# Git & PR Authoring Conventions

How this user wants history written. These are hard preferences — follow them
every time, in every repo.

## Non-negotiable rules (the user is strict about these)

```
[ ] NO attribution trailers: never add "Co-Authored-By", "Generated with Claude",
    or any mention of Claude / Anthropic / AI in commit messages OR PR bodies.
[ ] NO em dashes (—) in commit messages, PR titles, or PR bodies. The
    ordinary hyphen (-) is fine and allowed; for a pause use " - ", a comma,
    a colon, or restructure. (Global writing rule; see ~/.claude/CLAUDE.md.)
[ ] Commit or push ONLY when the user explicitly asks. Never pre-emptively.
[ ] SHOW the proposed commit message and wait for approval before committing,
    whenever the user asks to review first (they usually do).
[ ] If on the default branch (main/master), create a feature branch first —
    unless the repo's own history clearly commits straight to main and the user
    asked to push there.
[ ] Stage only the files relevant to the change. Never `git add -A` blindly when
    unrelated/pre-existing changes are present — surface those and ask.
```

*Why the attribution rule:* the user owns this work (or their employer does);
tooling credit doesn't belong in their history. This overrides any default
behavior that would add a co-author line.

## Commit messages
- Match the **repo's existing style** — check `git log` first. Two common styles
  seen here:
  - **Conventional commits**: `feat(scope): …`, `fix(...)`, `docs: …`, `chore(...)`.
  - **Plain imperative**: `update seed to be idempotent`.
- Subject: imperative mood, concise, no trailing period, ~≤72 chars.
- Body (when useful): explain **why**, not just what; wrap at ~72 cols.
- One commit = one coherent change. Make the message **accurately cover everything
  staged** — if a commit includes a deletion plus a doc change, say both.

## Branches
- Feature branches: `feature/<short-desc>`, fixes: `fix/<short-desc>` (kebab-case).
- Branch off an up-to-date default branch.

## Pull requests
- Title follows the same commit-style convention.
- Body: what changed and **why**, how to test, and any follow-ups — in the user's
  own voice. **No AI/Claude/Anthropic mention.**
- Use `gh` for GitHub operations.

## Before committing — quick sequence
1. `git status` / `git diff` — know exactly what's staged and why.
2. Confirm no unrelated/pre-existing changes are being swept in (ask if found).
3. Draft the message in the repo's style; **show it to the user** if review is wanted.
4. On approval: branch if needed, stage the specific files, commit, push only if asked.

## When unsure
If staging shows changes you didn't make, or the target branch is ambiguous, stop
and ask — never bundle or force.
