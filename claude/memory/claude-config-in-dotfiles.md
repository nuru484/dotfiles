---
name: claude-config-in-dotfiles
description: "~/.claude CLAUDE.md, settings.json and skills/ are symlinks into the ~/dotfiles git repo"
metadata: 
  node_type: memory
  type: project
  originSessionId: d885c59c-2a0a-4084-b1ac-2799bf01d591
  modified: 2026-08-15T19:07:18.393Z
---

Since 2026-08-15, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, and
`~/.claude/skills/` are symlinks pointing into `~/dotfiles/claude/`, a git repo
shared with a second PC. Editing any of them writes into the repo.

**Why:** the user runs Claude Code on two machines and wants a refined skill to
reach the other one via `git pull` instead of drifting.

**How to apply:** after changing a skill or the global CLAUDE.md, mention that
`~/dotfiles` has uncommitted changes so it can be pushed (respect
[[commit-no-ai-attribution]]: commit only when asked). If `~/.claude/settings.json`
ever stops being a symlink, Claude Code replaced it on write - move it back into
`~/dotfiles/claude/` and re-run `bash ~/dotfiles/claude/install.sh`.

Note: `~/.config/git/ignore` ignores `CLAUDE.md` and `.claude/` globally, so
per-project CLAUDE.md files are untracked everywhere unless a repo `.gitignore`
negates it (the dotfiles repo does).
