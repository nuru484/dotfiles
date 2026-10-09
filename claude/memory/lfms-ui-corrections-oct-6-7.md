---
name: lfms-ui-corrections-oct-6-7
description: "The UI corrections the owner made 6-7 Oct 2026 (headings, controls, filters, tables, photo page); rules are in lfms-web/CLAUDE.md, lessons here so they are never repeated"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 18c7de0a-c25e-4690-bbbd-9ba8acaac792
  modified: 2026-10-07T01:11:12.912Z
---

The binding rules live in lfms-web/CLAUDE.md, "Headings, controls and empty states (owner, 6 October 2026)". Read them before any screen work. What kept recurring, so check it on every new screen without being told:

- A section title starts level with its controls' top, the same 20px from the card edge as the buttons. This applies with or without a sentence; never centre a title on 40px buttons.
- Every titled section has a one-line sentence right under its title. Two lines are allowed beside controls, never three. A sentence without a title among titled cards is wrong.
- Controls stay on the heading row. Extra buttons fold into the actions menu, then the main button too, before the controls drop under the sentence.
- Shorten a sentence or a label rather than wrap.
- A summary ("1 missing") sits beside the title, toned with `summaryTone` warning or danger.
- A content width (`useTabPageMeasure`) holds the toolbar, filter panel and handed-up controls too. A filter panel never runs past its content.
- Tables never scroll sideways. `hideOnTablet` columns drop one at a time until the table fits.
- Never put a `//` comment inside JSX children. It renders as text (it did once, in the filter panel).
- One tree per header layout. Switching branches remounts the title and loses focus; this broke the notification categories.

**Why:** the owner re-reported the same heading and spacing faults on page after page (practice area, stage set, bank account, contacts, roles). Each fix had covered only one shape of header.

**How to apply:** fix in SectionCard, SectionList and the toolbar, never per page. After a change, run the header sweep and measure title-top against control-top. The scripts are in lfms-web/.hdrcheck.mjs, .probe.mjs and .shot.mjs, which are git-excluded. Links: [[fix-the-class-not-the-instance]], [[check-ui-live]], [[lfms-layout-corrections]].
