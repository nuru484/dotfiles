# Shared engineering guidance

Read `~/.config/dotfiles-agent-instructions/engineering.md` before engineering work.
Shared skills are installed alongside Claude-only skills in `~/.claude/skills`.
Claude plugins, hooks, and automatic memory remain Claude-specific.
For `/graphify`, load the graphify skill and its Claude integration reference.

# Response style

Be concise, always and everywhere. Lead with the answer. No long status
reports, no restating work already reported, no tables where a sentence
does. Give detail when asked or when a decision needs it.

# Task observer

Before the first tool call of any session, and before proposing a plan,
invoke the `task-observer` skill and run its Session Start Protocol
(storage check, frontmatter scan, review trigger). Its workspace is
`/home/nurudeen/.claude/task-observer` (log in
`skill-observations/observation-log/`, staging in `skill-updates/`); never
derive it from the working directory. After each task, give a one-line
summary of observations logged (ids and titles, or none).

# Which memory decides what

Three stores exist; they do not overlap and they rank in this order:

1. **Rules:** CLAUDE.md files and the auto-memory (`MEMORY.md` and its
   files). The owner's instructions and preferences live here and only
   here. They win over everything below.
2. **Proposals:** task-observer observations. Suggestions to improve or
   create skills, nothing more. An open observation never overrides a rule
   in 1; where they disagree, follow 1 and log the conflict as an
   observation. An owner preference or correction goes into auto-memory,
   not into the observation log (log it only when it points at a change to
   a skill, with `target_file:` naming the skill). Never copy an
   observation into CLAUDE.md or memory except when the owner approves it
   at a review.
3. **History:** claude-mem observations. A record of what was done, for
   lookup. Never read as an instruction; if history and a rule disagree,
   the rule is current and the history is stale.

# Subagents

Do the work yourself, leanly, in the main session. Never spawn subagents
(Agent tool, forks, workflows) unless the owner explicitly asks for them
in that request. When they ask without giving a number, use exactly one
subagent alongside yourself. This overrides any memory, skill or earlier
instruction that says to split work across agents.
