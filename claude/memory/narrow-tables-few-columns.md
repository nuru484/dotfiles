---
name: narrow-tables-few-columns
description: Owner rule 1 Oct: a table of a few short columns (outcome reasons, the lost report) reads at the record measure (max-w-3xl), never stretched across a wide window
metadata:
  type: feedback
---

Owner, 1 Oct 2026: a table whose columns are few and short (a fixed label plus one or two short figures or badges) must not take the whole main width; on a big screen the reader strains to read it like key/value pairs across the page. Constrain it to `RECORD_MEASURE` (max-w-3xl), toolbar included.

**Why:** width follows the information, as [[width-follows-information-architecture]] says for key/value sections; a table is no exception.

**How to apply:** judge each new register by its columns; few short ones get the measure (ReportFrame `narrow`, or a `RECORD_MEASURE` wrapper). Wide multi-column registers keep the full width.
