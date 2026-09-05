---
name: no-migrations-in-deploy-scripts
description: "User runs prisma migrations against prod manually before pushing — deploy scripts must NOT run `prisma migrate deploy`"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 623a90d4-3d85-49e6-b7c3-e0a36ac0e3a4
---

Deploy/build scripts in the user's backends (traveltrek, and per [[prod-db-is-neondb]] the same workflow on dms-backend) must not include `prisma migrate deploy`. The user applies migrations to the production database manually from their machine before pushing code.

**Why:** they don't want migrations running on every deploy; migrating prod is a deliberate, hand-run step in their workflow.

**How to apply:** deploy scripts should be `npm install --include=dev && npx prisma generate && npm run build` (the `--include=dev` matters on Render where NODE_ENV=production would otherwise skip @types/typescript). Never add `migrate deploy` back to a build/release script without asking; when a schema change ships, remind them to run the migration against prod before pushing.
