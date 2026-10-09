---
name: lists-controls-one-place
description: LFMS rule (owner 1 Oct 2026) - record-page lists keep search/filters/buttons INSIDE their card; workspace registers keep them above the table; empty unfiltered lists show no filters; no duplicate registers (People replaced Settings > Users)
metadata:
  type: feedback
---

On a record's page every list is one card with its controls inside at the top and rows flush; on a workspace page the toolbar stands above the table. `RegisterFrame` (table-section.tsx) draws both; a nested SectionCard dissolves into its parent. Empty lists with no filter applied show only the empty state and its action. One register per concern: People is the user administration, Settings > Users removed.

**Why:** owner, 1 Oct 2026: some detail pages had controls inside the card and some outside ("there should be one global pattern"); filters on an empty list "for what?"; Settings > Users beside People is "tautology".

**How to apply:** build every new register with `RegisterFrame`; guard `test/unit/register-frame.test.ts`; never add a second list of the same records in Settings. Written into lfms-web CLAUDE.md. Related: [[fix-the-class-not-the-instance]], [[every-list-searchable]].
