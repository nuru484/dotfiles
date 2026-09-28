---
name: lfms-deploy-migrates
description: LFMS pushes apply Prisma migrations automatically on deploy; push without waiting for a manual migrate (unlike other repos)
metadata:
  node_type: memory
  type: project
  originSessionId: 984271e8-5394-42a5-96f1-847c85be87a3
  modified: 2026-09-27T19:55:27.208Z
---

For lfms-api, pushing to main deploys and the deploy runs the migrations
itself (owner, 2026-09-27). Do not hold a push waiting for the owner to
migrate production by hand; [[no-migrations-in-deploy-scripts]] applies to
the owner's other backends, not LFMS.

The preview deployment runs without the worker on purpose (owner,
2026-09-27): anything that needs the worker (virus scan, previews, queued
jobs) is expected to stall there until the owner starts it. Do not report
that as a fault.

**Why:** the owner corrected a held push on 2026-09-27.
**How to apply:** push LFMS API before web when the contract changes, and
push without asking for a manual migration.
