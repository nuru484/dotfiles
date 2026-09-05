---
name: run-lint-before-commit
description: "Node/TS backends use eslint perfectionist (alphabetical keys) — run the repo lint before committing, tsc+tests isn't enough"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0755b1d3-1053-40a2-b93a-94544eae3a14
---

The khadys-kitchen backend (and the sibling dms/website backends, which share
the same stack) run `eslint .` in CI via the `lint` npm script, with the
**perfectionist** plugin enforcing alphabetical ordering of object keys
(`sort-objects`), object-type members (`sort-object-types`), and imports. A
misplaced key fails CI even though `tsc --noEmit` and the test suite both pass.

**Why:** a green typecheck and green tests are NOT sufficient — these repos gate
merges on lint, and perfectionist flags ordering that has zero runtime effect.

**How to apply:** before committing/pushing backend changes, run `npm run lint`
(or `npx eslint <changed files> --fix`) — not just tsc + vitest. `--fix`
auto-resolves the ordering rules. Add new object keys in alphabetical position
to begin with. Related: [[commit-no-ai-attribution]].
