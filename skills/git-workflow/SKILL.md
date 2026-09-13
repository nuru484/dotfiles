---
name: git-workflow
description: "Author commits, branches, and pull requests within the user-authorized scope. Apply for Git mutations and PR authoring, not routine file edits or read-only status checks."
---

# Git and pull-request authoring

Inspect status and diff before staging. Include only task-relevant changes;
leave unrelated user edits intact. Ask only if a shared hunk cannot be separated
safely or the requested target is genuinely ambiguous.

## Authorization and history

- In interactive work, commit when requested. Existing authorization is enough;
  do not require a second message approval unless the user requested review first.
- In an explicitly unattended end-to-end build, coherent milestone commits are
  the user's default. Ordinary requests for several edits are not such a build.
- Push and open PRs only when explicitly requested or included in task instructions.
- Prefer feature/<name> or fix/<name> off the appropriate base. Respect an explicitly
  requested branch and repository workflow. Never discard changes to switch branches.
- Do not amend, rebase, or force-push shared/reviewed history without explicit scope.
  Authorized private-branch rewrites use --force-with-lease, not bare --force.

## Checks and hooks

Run required project checks before committing and inspect their output. Existing
passing evidence remains valid for unchanged work, although Git hooks may repeat
checks mechanically. Fix hook failures within scope; bypass hooks only when the
user explicitly authorizes it. Do not use obsolete CLAUDE_SKIP_COMMIT_GATE settings.

Global hooks live under ~/.git-hooks when installed. A repository using Husky or
another core.hooksPath overrides them; inspect the effective hook before claiming
checks are enforced. Changing project hooks is a separate setup task, not an
automatic addition to every commit.

## Messages and PRs

Match repository commit style. Prefer a short imperative summary of the complete
staged change; add a body when the reasoning is not apparent. Follow shared writing
preferences and omit unsolicited assistant attribution trailers. Technical mentions
of agent products are appropriate when they are the subject of the change.

PR descriptions explain the problem, resulting behavior, relevant validation, and
material risks. Scale detail to complexity and use the repository template. Keep
multiline bodies in a file or structured argument so shell interpolation cannot
change their contents. Verify the resulting commit/PR state before reporting it.
