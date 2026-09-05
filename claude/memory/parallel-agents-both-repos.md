---
name: parallel-agents-both-repos
description: "Build lfms-api and lfms-web (and any paired backend + frontend) in parallel with subagents, several plan steps at once, syncing generated contract types between them"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b90ced91-69c6-48da-8759-629929cc8bf5
  modified: 2026-09-05T00:25:52.022Z
---

When a build spans a backend and a frontend repo (lfms-api and lfms-web
are the standing case), do not work them one after the other in the main
session. Split the work across subagents: one (or more) on the API, one
(or more) on the web app, running at the same time, and take on several
build-plan steps in one pass rather than one milestone at a time.

The handshake between them is the generated contracts: the API agent
finishes its schemas, then `npm run contracts:sync` in lfms-api regenerates
`@lfms/contracts` and copies it into `lfms-web/src/contracts`. The web
agent starts from synced types; where it starts before the API is done it
works against the operation shapes the plan names and the sync catches
any drift through the parity test.

**Why:** the user asked for it on 2026-09-05 after watching the API and web
for one milestone get built serially; the two repos never conflict on
disk, so serial work only wastes wall clock.

**How to apply:** for any "proceed with the plan" or multi-step feature
request touching both repos, (1) do the shared groundwork yourself (schema
or contract decisions), (2) spawn an API agent and a web agent in the same
message with the exemplar module named and the gates to run, (3) sync
contracts when the API side lands, (4) run each repo's full gate once at
the end. Agents working in the same repo must not touch the same files
(schema.prisma, modules.ts, catalogue.ts, seed-roles.ts, nav.ts are the
usual collision points), so one agent per repo unless the work is
file-disjoint. See [[lfms-graphify-graphs]] for the code map and
[[commit-no-ai-attribution]] for commits.
