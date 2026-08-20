# dotfiles

Personal machine config, kept in git so it stays identical across computers.

## Claude Code (`claude/`)

| File | What it is |
| --- | --- |
| `CLAUDE.md` | Global instructions + engineering standards applied to every project |
| `settings.json` | Model, effort level, theme, permissions, plugins, hooks |
| `skills/` | Personal skills covering the full build lifecycle |
| `hooks/` | Hook scripts (pre-commit quality gate) wired via settings.json |

The skills are designed to carry an end-to-end build from a system design
document with minimal prompting:

- **Plan**: `app-blueprint` (design doc -> PLAN.md, domain modeling, default decisions)
- **Scaffold**: `project-scaffold` (canonical infra modules, bootstrap, local dev)
- **Build**: `backend-conventions`, `frontend-conventions`, `api-contracts`,
  `database-migrations`, `auth-conventions`, `saas-integrations`
- **Quality**: `tdd` (test-first, default methodology), `mobile-first-ui`,
  `web-design-guidelines`, `security-hardening`, `observability`,
  `vercel-react-best-practices`, `vercel-composition-patterns` (vendored, with house overrides)
- **Craft** (vendored from [emilkowalski/skills](https://github.com/emilkowalski/skills),
  with house overrides): `emil-design-eng`, `animate`, `review-animations`,
  `improve-animations`, `find-animation-opportunities`, `animation-vocabulary`,
  `apple-design`, `ask-sonner`, `pick-ui-library`, `prototype`, `animate-expo`;
  plus `design-taste` (anti-slop defaults + marketing composition, adapted
  from [Leonxlnx/taste-skill](https://github.com/leonxlnx/taste-skill), MIT)
- **Ship**: `git-workflow`, `ci-cd`, `release-deploy`
- **Method** (vendored from [obra/superpowers](https://github.com/obra/superpowers), MIT):
  `systematic-debugging` (root cause before fixes, always),
  `verification-before-completion` (no success claims without fresh evidence)
- **Meta**: `find-skills`

The two-layer design: universal skills (app-blueprint, tdd, git-workflow,
debugging/verification, CLAUDE.md standards - the latter also carrying
Karpathy-derived rules on simplicity, surgical changes, and surfaced
assumptions) apply to any software; stack profiles encode the house web
stack and stay silent elsewhere. Ownership and conflict precedence live in
`CLAUDE.md`. A commit-gate hook (`hooks/pre-commit-gate.sh`, wired in
`settings.json`) mechanically blocks `git commit` while a repo's
lint/typecheck/test scripts fail.

### Vendored-skill upkeep

Vendored packs and their upstreams: `vercel-*` (vercel-labs/agent-skills),
`emil-*`/`animate*`/`apple-design`/`ask-sonner`/`pick-ui-library`/`prototype`
(emilkowalski/skills), `design-taste` (adapted from Leonxlnx/taste-skill),
`systematic-debugging` + `verification-before-completion` (obra/superpowers).
To re-sync one: clone upstream, diff against the vendored copy, re-apply the
house edits (each pack's SKILL.md header lists them), re-run the em-dash
sweep. Occasionally run the skill-creator plugin's description-optimization
evals on the always-on skills.

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
