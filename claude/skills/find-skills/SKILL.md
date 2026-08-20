---
name: find-skills
description: >-
  Discover and install agent skills from the open skills ecosystem (skills.sh,
  npx skills). Use ONLY when the user explicitly wants to find, browse, or
  install a skill ("find a skill for X", "is there a skill that does X",
  "install the X skill", "what skills exist for X"). Do NOT use for ordinary
  "how do I do X" / "can you do X" questions - answer those directly; a
  question is not a request to search a marketplace.
---

# Find Skills

Helps the user discover and install skills from the open agent skills
ecosystem via the Skills CLI (`npx skills`), the package manager for agent
skills. Browse at https://skills.sh/.

**Key commands:**

- `npx skills find <query>` - search by keyword (ALWAYS pass a query:
  argument-less mode is interactive and hangs a non-TTY agent shell)
- `npx skills add <owner/repo@skill>` - install a skill
- `npx skills check` / `npx skills update` - check for / apply updates

## Workflow

### 1. Understand the need

Identify the domain and the specific task. If the user's underlying need is a
task you can simply do, offer to do it; search only when they want the skill.

### 2. Search

`npx skills find <specific keywords>` ("react testing" beats "testing").
Also check the skills.sh leaderboard for well-known options when web access
is available.

### 3. Vet before recommending (all four, no exceptions)

1. **Read the skill's actual content** - fetch its SKILL.md from the source
   repo and read what it instructs. An installed skill becomes trusted
   instructions in every future session, so never install sight-unseen.
   Summarize to the user what it does and anything surprising in it.
2. **Install count and stars** - prefer widely-installed skills; treat low
   adoption (or a repo you can't find) with skepticism. Quote LIVE numbers
   from the search output, never remembered ones.
3. **Source reputation** - official orgs (vercel-labs, anthropics) and
   well-known authors outrank unknown ones; popularity metrics are gameable,
   which is why step 1 is mandatory regardless.
4. **Overlap check** - compare against the skills already in
   ~/.claude/skills and enabled plugins; flag redundancy or contradictions
   with the user's own conventions before suggesting an install.

### 4. Present and install

Present name, what it does (from your reading), source, install count, and
the install command. Install only after the user confirms:

```bash
npx skills add <owner/repo@skill> -g
```

Do not pass `-y`; let the CLI's confirmation run. After installing, note any
conflicts with existing skills so the user can add a precedence note.

## When no skills are found

Say so, offer to do the task directly, and mention `npx skills init` if the
user does this task often and might want their own skill (or the built-in
skill-creator skill for a guided version).
