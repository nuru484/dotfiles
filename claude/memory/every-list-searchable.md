---
name: every-list-searchable
description: LFMS rule — every list (registers AND lists on detail pages) has server search and filters; growing lists also page on the server; fixed lists no pager; hierarchies sort highest first
metadata:
  node_type: memory
  type: feedback
  originSessionId: 7239d7a3-327e-4e89-aeb1-96ea371ea276
  modified: 2026-09-29T03:59:35.726Z
---

Every list in LFMS, registers and the lists under a record on detail
pages alike, has a search box and filters, answered by the server. A list
that shows dates also has a date range filter.

- **A list that grows** (records, history, anything the firm adds to over
  time, or sized by headcount): search, filters, date range where it has
  dates, sort, and pagination, all server side. Never fetch it whole and
  filter or page in the browser (`pageOf` over a whole list is the smell).
- **A fixed list** (always around 10 to 15 rows: the firm's practice
  areas, a year's holidays, approval routes, its registrations): search
  and filters, sort if it helps, and no pager; it may read whole.
- **A hierarchy** sorts by rank by default: roles managing partner first,
  courts supreme court first.
- **A dropdown whose options can grow** (people, lawyers, parties,
  matters, courts) is a server-searched picker, never a first page of
  options (lfms TODO F2).
- A list that genuinely should not follow this is raised with the owner,
  never silently left. The API guard is
  `src/contracts/__tests__/lists-are-paged.test.ts` (paging and the
  `NO_SEARCH` allowlist); the shared helpers are
  `src/platform/http/list-filters.ts` (API) and `useDebouncedValue` (web).

**Why:** the owner, 28 and 29 September 2026: the firm's users are often
older people who search or filter by what they know rather than page
through; they found Banking, Unbilled and Write-offs without it, and asked
for it on every list including detail pages.
**How to apply:** audit before building any list; change the endpoint
(query params) and the screen together; test the server narrowing.
Related: [[phone-content-first]], [[fix-the-class-not-the-instance]],
[[lfms-fixes-2026-09-29]].

**Reaffirmed 30 Sep 2026 (owner, after S3 shipped lists and reports without search):** EVERY list has search, even one of 10 rows, including reports and lists under a record; filters where it has anything to filter by; sorting where it has an order. No `NO_SEARCH` exemption is an answer to a new list: add the server search instead (the S3 session wrongly exempted intake consultations/proposals and had to undo it). Pagination only for growing lists, and the pager shows only past the system's established threshold.
