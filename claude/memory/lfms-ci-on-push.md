---
name: lfms-ci-on-push
description: LFMS CI is manual (workflow_dispatch) again to save Actions minutes (owner 5 Oct 2026); run and watch it when a push needs it
metadata:
  type: feedback
---

Owner, 5 October 2026: turned CI on for every push, then the same evening: "the github ci is taking forever ... I think you should turn the ci off again from github, so my minutes can be utilised, though it normally reveals some errors we don't see locally".

lfms-api and lfms-web CI run by hand only (`gh workflow run CI --ref main`); lfms-site still runs on push. CI fixes kept: coverage floors only on the merged report, 6 GB heap for the web typecheck, web test shards at two workers with a 1200 MB VM memory cap. The web shards had failed since 22 Sep with screens missing their waits on the starved runner; whether the worker cap cures it is unproven (run cancelled).

**Why:** Actions minutes are limited; the full suites take long on GitHub's runners.
**How to apply:** the full local gate is the bar before every push, and its EXIT is read before pushing. Dispatch CI only when the owner asks or a change needs the GitHub environment (Dockerfile, workflow, runner-only failures), then watch it to the end.
