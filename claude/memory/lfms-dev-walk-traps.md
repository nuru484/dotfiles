---
name: lfms-dev-walk-traps
description: LFMS live-walk and commit traps - session minting for walks, SSO mode, playwright path, .next/types clash, commit hook staging and limits
metadata:
  type: reference
---

- Walk sign-in: mint a session with `createSession` + `signCookieValue` (tsx script with `--env-file=.env`) and set `lfms_session` via document.cookie; SSO stays "required". For password walks instead, set setting `identity.sso_mode` to "optional" and restore "required".
- Walk scripts live in the scratchpad and must be copied into lfms-web to resolve playwright-core.
- `.next/types` from a production build clashes with dev types: delete `.next/types`.
- Commit hooks: stage tests in one call, commit in the next; a failed `git add` pathspec still lets the commit run on what was staged. The lfms-api hook takes ~15 min (lint-staged + full typecheck), refuses any AI trailer and commit body lines over 100 characters.
- Integration test clocks must sit before today (step-up is stamped with real time); the memory payment provider persists across tests in a file.
- Reseeding dev: `npm run seed` then `npm run seed:demo` (fixed 6 Oct: the demo acts as whoever holds the managing partner seat). `prisma migrate reset` fails on the DB's own functions; recreate with `DROP DATABASE lfms WITH (FORCE)` + `CREATE DATABASE lfms OWNER nurudeen` + `prisma migrate deploy`.
- After a crash the test cluster on :5433 is gone: `scripts/db/test-postgres.sh up` (npm's pretest does it; `npx vitest` does not).
