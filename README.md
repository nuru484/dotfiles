# dotfiles

Personal configuration and a shared skill library for Claude and Codex.

## Layout

| Path | Purpose |
| --- | --- |
| `skills/` | Shared skill source, supporting references, and vendor licenses |
| `instructions/engineering.md` | Shared preferences, task ownership, and verification rules |
| `claude/skills/` | Claude-only skills |
| `codex/skills/` | Codex-only skills |
| `claude/CLAUDE.md`, `codex/AGENTS.md` | Host entrypoints for shared instructions |
| `claude/settings.json` | Claude settings and plugin connections |
| `claude/memory/` | Existing Claude automatic memory; not Codex memory |
| `scripts/install-agent.py` | Shared/host-only installation and metadata conversion |
| `git/hooks/` | Git checks independent of the coding agent |
| `tests/` | Offline installer tests and behavioral evaluation scenarios |

## Install

From a checkout, install skills and instructions for the hosts in use:

```bash
python3 scripts/install-agent.py claude
bash codex/install.sh
```

Claude receives individual links under `~/.claude/skills`; Codex receives them under
`~/.agents/skills`. Each installation directory remains a real directory, so external
installers can add local skills without writing into the shared source. The entrypoints
read the common instructions through `~/.config/dotfiles-agent-instructions`.
Existing files are backed up with unique names. Re-running an unchanged installation
does not create duplicate backups. Source removal does not prune installed links;
remove the corresponding link deliberately when retiring a skill.

The installers preserve settings and unrelated skills. They do not connect plugins,
install Graphify, or change Git configuration. For full new-machine Claude/Git/Graphify
setup, use `bash claude/install.sh`; this also links the existing home-project Claude
memory and configures global Git hooks/ignore. It preserves previous backups.

Run the appropriate installer after adding skills or changing host metadata. Most
shared content edits follow symlinks immediately. Skills with Claude-only invocation
metadata get generated Codex entrypoints under `~/.local/share/dotfiles-codex-skills`;
re-run the Codex installer after editing their SKILL.md. Supporting resources remain
linked to source. Restart the host if new skill discovery does not refresh.

## Shared versus host-only

Add portable SKILL.md folders to `skills/`. Put a Claude memory integration or a
skill depending on Claude runtime fields in `claude/skills/`, and Codex-only workflows
in `codex/skills/`. Plugins stay in the host's plugin configuration. Credentials,
session state, caches, and transcripts remain machine-local.

Shared and host-only skill names must be distinct; installation rejects collisions.
Codex conversion removes supported Claude invocation metadata, including multiline
argument hints. Explicit-only skills must also declare
`policy.allow_implicit_invocation: false` in `agents/openai.yaml`. Runtime fields such
as `context`, `agent`, `model`, or `hooks` are rejected for Codex rather than silently
dropping the behavior. Create a separate host-specific implementation for those cases.

## Skill maintenance

- A description names the skill set it belongs to (web, API, database; see
  `instructions/engineering.md`) and the work that loads it, stated positively. It
  never invites skipping the skill for a small edit; the set loads whole.
- SKILL.md contains essential decisions and completion evidence. Detailed recipes
  belong in references loaded only for the affected concern.
- Shared instructions own universal preferences; individual skills own domain rules.
  Preserve real invariants without duplicating global process requirements.
- Existing project architecture and explicit user choices override personal defaults.
  Reference examples must be checked against installed APIs before adaptation.
- Run structural validation and the offline installer tests after changes. Re-run
  relevant scenarios from `tests/skill_scenarios.md` for substantial workflow changes.
  Record actual evidence; design exercises are not application runtime tests.

```bash
python3 -m unittest discover -s tests -p 'test_*.py'
```

The skill-creator validator can additionally validate installed Codex skill folders.
For scripts and runtime recipes, use real behavior tests with isolated fixtures;
checking that expected wording exists is not a substitute.

## Git enforcement

When configured, `git/hooks/pre-commit` checks staged-file policy and invokes
`quality-gate.sh`. For Node repos it runs declared lint/typecheck/test scripts using
the project package manager and CI=true. The existing commit-message policy remains
in `message-rules.sh`; `post-commit` updates an already-existing Graphify graph.
The old Claude tool hook is a no-op compatibility entrypoint, so it does not run the
same checks twice. Repositories with their own core.hooksPath must wire shared checks
explicitly. CI remains the release authority; local hooks can be bypassed.

## Vendored content

Preserve upstream LICENSE files and THIRD_PARTY_NOTICES.md when updating skills.
Vendored sources include vercel-labs/agent-skills, emilkowalski/skills,
Leonxlnx/taste-skill, obra/superpowers, and Graphify-Labs/graphify. Review upstream
changes in a temporary checkout and reapply the task boundaries and local decisions;
do not overwrite the shared source with an upstream installer.

Claude may replace settings.json while saving settings, breaking its symlink. If
that occurs, reconcile the local settings with the dotfiles source before reinstalling;
do not discard the local version.
