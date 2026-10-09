---
name: lfms-speed-at-firm-size
description: "LFMS performance is judged at a large firm's size; query budgets, per-request memo, counts in SQL; rules live in lfms-api CLAUDE.md (owner 8 Oct)"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 7134d0d2-3d09-4e60-8c47-59cb7e6774ed
  modified: 2026-10-08T21:29:24.964Z
---

Owner (8 Oct 2026) wants the whole system fast, efficient and scalable for large firms, from now on in every change, and asked for a full performance pass.

**Why:** the preview API died of memory and the sidebar badge cost 120 queries a request; the owner said the UI work means nothing if the server is slow.

**How to apply:** follow the "Fast at a large firm's size" block in lfms-api/CLAUDE.md (budgets 300 ms / 15 queries per read, query count flat with rows, counts in SQL, EXPLAIN on the large-firm seed, `memoInRequest` for repeated reads, no process caches). Read the access log's heavy-request warnings after every walk. The performance program is tracked in work state list `perf-program`. Related: [[lfms-law-is-data]], [[enterprise-complete-linked-entities]].
