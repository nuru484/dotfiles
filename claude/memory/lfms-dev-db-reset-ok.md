---
name: lfms-dev-db-reset-ok
description: Owner allows resetting or clearing the LFMS local dev database at any time; the seed rebuilds it
metadata:
  node_type: memory
  type: feedback
  originSessionId: d50203ff-22f1-4ed2-b55e-eb5869303dba
  modified: 2026-10-01T08:16:49.157Z
---

The owner said (1 Oct 2026): "you can always reset the db, and make updates, you can even clear it, since we can always rerun the seed to get fresh new data. so yeah, you can reset it."

**Why:** demo data is disposable (see [[lfms-no-firm-data]]); a stale demo (people in the wrong office) blocked a live walk.

**How to apply:** local dev DB only (`lfms` on localhost), never preview or prod. Prisma 7 refuses `migrate reset` from an agent unless `PRISMA_USER_CONSENT_FOR_DANGEROUS_AI_ACTION` holds the owner's exact consent words; pass the quote above verbatim. Then `npm run seed` and `npm run seed:demo`.
