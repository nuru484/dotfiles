---
name: lfms-tab-subheadings
description: "LFMS every tab page opens on its subheading from PAGE_TAB_DESCRIPTIONS with the page's controls beside it; never exempt a tab or put the sentence in a card"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5087a1d5-35c4-47a4-8722-4e5c09cfd52b
  modified: 2026-09-29T08:02:23.338Z
---

Every tab page in lfms-web opens on its one-sentence subheading under the tab row (`src/static-data/page-tab-descriptions.ts`), and the page's own controls stand beside it through `TabPageSectionHeader` / `TabPageIntroPromotion`, never as a SectionCard description and action. Do not add entries to the `HANDS_UP_ITS_OWN` exemption list in `test/unit/tab-descriptions.test.ts`; that list is how Week and Timers lost their subheadings.

**Why:** owner fixed this system-wide once and it came back on 29 Sep 2026 (Week, Timers): "I said it should be remembered throughout, why is it repeated again?"

**How to apply:** when building or rebuilding any tab page, add its sentence to the map and hand controls up; check at 344 that the sentence keeps its width and stood-down controls share the row. Related: [[phone-content-first]], [[lfms-layout-corrections]].
