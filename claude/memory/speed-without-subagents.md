---
name: speed-without-subagents
description: Owner-approved ways to work faster on LFMS without subagents: one sign-in per walk, one full gate per session in the background, one walk at the end, terse status, keep the Codex lane full
metadata:
  type: feedback
---

Work faster without subagents (owner, 1 Oct 2026: "this fixes has been kinda slow, if there are ways to speed up things without sub agents, I will welcome that"):

1. **Sign in once per session.** The Playwright walk saves the signed-in storage state to the scratchpad on first login and reuses it; never re-login per screen (each re-login waited up to 30s for a fresh TOTP window, and replaying a code is refused).
2. **One full gate per repo per session, at the end, in the background** while writing help, PLAN and the Desktop log. While building, run only the tests around the change. Never wait idle on a suite. `vitest run -u <file>` runs the WHOLE suite: update a snapshot with `npx vitest run <file> -u` only after confirming the file filter, or delete and re-record the one snapshot.
3. **One live walk per session**, at the end: every changed screen, every width (1920 included, see [[check-ui-live]]), one script, one login; fix and re-shoot only the failures.
4. **Terse status**: one line when something finishes; no step-by-step narration (see [[concise-responses]]).
5. **Keep the Codex lane full**: it is the parallel capacity that is not a subagent. When its queue nears empty, write the next fully-decided specs before it runs dry (see [[codex-lane-owns-sessions]]).

**Why:** a day's sessions spent much of their time on repeated full suites (4 web runs, 2 API runs at 10-15 min each), repeated logins and per-step walks.

**How to apply:** plan each session as build (targeted tests) → one background full gate + one walk → commit → log. Related: [[run-targeted-tests]], [[no-subagents-by-default]].
