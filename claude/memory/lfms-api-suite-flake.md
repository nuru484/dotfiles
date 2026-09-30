---
name: lfms-api-suite-flake
description: "lfms-api's integration suite failed one test file once in five runs on 2026-09-06 and has not reproduced; capture full gate output so the next occurrence is diagnosable"
metadata:
  node_type: memory
  type: project
---

On 2026-09-06, verifying M24 at commit b35d5f4, one run of `npm test` in
~/repos/lfms-api reported `Test Files 1 failed | 145 passed` and
`Tests 1 failed | 958 passed`. Four further runs of the same commit all
passed 959. The failing file was never identified because the command
piped the reporter through `tail -5`, which kept only the summary.

**Identified 2026-09-06 by the seed agent, which saw it under load:**
`test/integration/identity/mfa-email.test.ts` builds a time-based code for
the previous 30 second step and fails when activation is slow, which is why
it only appears on a loaded machine and never in isolation. The fix is to pin
the clock in that test rather than compute a code against the wall clock.

Superseded suspicion, recorded so nobody chases it again: `test/setup.ts` truncates every
table before each test and retries when that collides with a write still
in flight, but the retry only fires when the error message contains
"deadlock". A lock timeout, or the same collision worded differently by
Postgres, would throw instead of retrying and would surface as exactly one
failed file at random. Nothing has proved this is the cause.

**How to apply:** never pipe a gate run through `tail`; write the full log
to a file and tail the file, so an intermittent failure is diagnosable the
first time it happens. When it recurs, read the failing file and the
assertion before touching the harness. Do not broaden that retry on
suspicion alone: a wider catch in test setup could mask a genuine lock
problem in the code under test. See [[milestone-start-grounding]].


**Identified 2026-09-29:** billing/bill-rules.test.ts "numbers twenty bills posted at once" (~6s alone, >20s under 7 parallel workers); given a 60s limit in commit 6e8f043b on main.
