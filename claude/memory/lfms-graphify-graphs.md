---
name: lfms-graphify-graphs
description: "Where the graphify knowledge graphs for lfms-api and lfms-web live, how they were built (2026-09-04) and how to refresh them"
metadata: 
  node_type: memory
  type: reference
  originSessionId: b90ced91-69c6-48da-8759-629929cc8bf5
  modified: 2026-09-04T21:55:25.496Z
---

LFMS knowledge graphs built 2026-09-04 with graphify 0.9.50 (interpreter
recorded in each graphify-out/.graphify_python):

- ~/repos/lfms-api/graphify-out (graph.json, graph.html, GRAPH_REPORT.md)
- ~/repos/lfms-web/graphify-out (same)
- ~/repos/lfms-graph/graphify-out/graph.json is the cross-repo merge of the
  two (nodes carry a `repo` attribute); graph.html there is community level.

graphify-out/ is ignored by the global git excludes file, so building never
dirties a working tree. Docs were extracted per repo with 8 subagents; the
brand PNGs and docs/design/phase-0-foundation.html in lfms-web were skipped
and are left unstamped in the manifest.

**How to apply:** for code-only changes run `graphify update <repo>` inside
the repo, then re-run `graphify merge-graphs` for the cross-repo file.
Answer architecture questions with `graphify query "<q>"` from the repo root
before reading files. See [[deployment-urls]] for the LFMS repos context.
