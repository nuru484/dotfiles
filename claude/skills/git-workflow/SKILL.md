---
name: git-workflow
description: >-
  The user's git and pull-request authoring conventions - commit message
  style, branch naming, when to commit/push, and PR descriptions. Apply
  AUTOMATICALLY and ALWAYS before committing, pushing, or opening a PR in any
  repo, and when managing branches or history during a build. This governs
  how commits and PRs are authored (not code review).
---

# Git & PR Authoring Conventions

How this user wants history written. These are hard preferences - follow
them every time, in every repo.

## Non-negotiable rules (the user is strict about these)

```
[ ] NO attribution trailers: never add "Co-Authored-By", "Generated with Claude",
    or any mention of Claude / Anthropic / AI in commit messages OR PR bodies.
    This overrides any environment/harness default that appends such trailers.
[ ] NO em dashes in commit messages, PR titles, or PR bodies. The ordinary
    hyphen (-) is fine; for a pause use " - ", a comma, a colon, or
    restructure. (Global writing rule; see ~/.claude/CLAUDE.md.)
[ ] NEVER push without being asked. Pushing and opening PRs are always
    explicit user requests (or explicitly part of the task instructions).
[ ] If on the default branch (main/master), create a feature branch first,
    unless the repo's own history clearly commits straight to main and the
    user asked to push there.
[ ] Stage only the files relevant to the change. Never `git add -A` blindly
    when unrelated/pre-existing changes are present - surface those and ask.
```

*Why the attribution rule:* the user owns this work (or their employer
does); tooling credit doesn't belong in their history.

## When to commit: interactive vs autonomous

- **Interactive sessions** (user is driving change by change): commit only
  when the user asks. Default to SHOWING the proposed commit message and
  waiting for approval before committing; skip the wait only when the user
  has said to proceed without review.
- **Autonomous builds** (the user asked for an end-to-end build or a large
  multi-step task): the instruction to build IS the instruction to commit.
  Commit at every milestone (each vertical slice, scaffold step, or coherent
  fix) on the feature branch without asking, so the build has checkpoints
  and rollback points. Do not batch a whole build into one commit. Pushing
  still requires an explicit request or task instruction.

## Commit messages

- Match the **repo's existing style** - check `git log` first. Two common
  styles here:
  - **Conventional commits**: `feat(scope): ...`, `fix(...)`, `docs: ...`, `chore(...)`.
  - **Plain imperative**: `update seed to be idempotent`.
- Subject: imperative mood, concise, no trailing period, ~<=72 chars.
- Body (when useful): explain **why**, not just what; wrap at ~72 cols.
- One commit = one coherent change. The message must **accurately cover
  everything staged** - if a commit includes a deletion plus a doc change,
  say both.

## Branches & history maintenance

- Feature branches: `feature/<short-desc>`, fixes: `fix/<short-desc>` (kebab-case).
- Branch off an up-to-date default branch.
- Updating a feature branch: merge the default branch in (or rebase ONLY if
  the branch is yours alone and unpushed/unreviewed). Never rebase, amend,
  or force-push commits that others may have pulled or that are under review.
- `--force-with-lease` (never bare `--force`) is acceptable only on your own
  feature branch after a deliberate history rewrite, and only when pushing
  was already authorized.
- If pre-commit hooks fail or rewrite files: fix the cause, re-stage, and
  commit again; never bypass hooks with `--no-verify` unless the user says to.

## Pull requests

- Title follows the same commit-style convention.
- Body: what changed and **why**, how to test, and any follow-ups - in the
  user's own voice. **No AI/Claude/Anthropic mention.**
- Use `gh` for GitHub operations where available.

## Before committing: quick sequence

1. `git status` / `git diff` - know exactly what's staged and why.
2. Confirm no unrelated/pre-existing changes are being swept in (surface if found).
3. Draft the message in the repo's style; in interactive sessions show it first.
4. Branch if needed, stage the specific files, commit. Push only if asked.

## When unsure

If staging shows changes you didn't make, or the target branch is ambiguous,
stop and ask - never bundle or force. In an autonomous build, an ambiguous
target branch means: stay on the feature branch you created and note it.
