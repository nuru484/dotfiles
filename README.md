# dotfiles

Personal machine config, kept in git so it stays identical across computers.

## Claude Code (`claude/`)

| File | What it is |
| --- | --- |
| `CLAUDE.md` | Global instructions + engineering standards applied to every project |
| `settings.json` | Model, effort level, theme, permissions, enabled plugins |
| `skills/` | Personal skills covering the full build lifecycle |

The skills are designed to carry an end-to-end build from a system design
document with minimal prompting:

- **Plan**: `app-blueprint` (design doc -> PLAN.md, domain modeling, default decisions)
- **Scaffold**: `project-scaffold` (canonical infra modules, bootstrap, local dev)
- **Build**: `backend-conventions`, `frontend-conventions`, `api-contracts`,
  `database-migrations`, `auth-conventions`, `saas-integrations`
- **Quality**: `tdd` (test-first, default methodology), `mobile-first-ui`,
  `web-design-guidelines`, `security-hardening`, `observability`,
  `vercel-react-best-practices`, `vercel-composition-patterns` (vendored, with house overrides)
- **Ship**: `git-workflow`, `ci-cd`, `release-deploy`
- **Meta**: `find-skills`

These are symlinked into `~/.claude/` rather than copied, so editing a skill
here takes effect immediately and a `git pull` updates the other machine.

### Set up on a new machine

Install Claude Code and sign in once, then:

```bash
git clone git@github.com:<user>/dotfiles.git ~/dotfiles
bash ~/dotfiles/claude/install.sh
```

Anything the installer would overwrite is renamed to `*.pre-dotfiles` first.

Two things the repo deliberately does not carry:

- **Plugins** re-install themselves from `settings.json` on first run.
- **MCP servers** are per-machine. Re-add with `claude mcp add`.

### Day to day

```bash
cd ~/dotfiles && git add -A && git commit -m "..." && git push   # after editing
cd ~/dotfiles && git pull                                        # on the other machine
```

### Note on `settings.json`

Claude Code writes to this file itself (theme changes, plugin installs). If it
ever saves by replacing the file instead of editing in place, the symlink turns
back into a regular file and this repo stops receiving updates. After changing a
setting, `ls -la ~/.claude/settings.json` should still show a `->` arrow. If it
does not, move the file back into `claude/` and re-run `install.sh`.

## Not included

Session transcripts, history, caches, credentials, and auto-memory all live in
`~/.claude/` and stay machine-local by design.
