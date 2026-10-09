---
name: section-heading-sentences
description: LFMS detail-page sections - a titled section's sentence is ONE line; a section named by its tab (sentence only) wraps to TWO lines; a fixed minimum gap between the words and the right-side controls
metadata:
  type: feedback
---

On detail pages: a section with its own heading keeps its sentence to one line (write it short; wrapping is rare). A section that takes the tab's name as its heading and shows only the sentence wraps that sentence to two lines however short it is, so the left side carries the same weight as the controls on the right. Between the words and the controls there is a fixed minimum space that never shrinks below it (it may grow).

**Why:** owner, 8 Oct 2026: "follow strictly ... to balance the weight to the right side controls ... enough fixed space between the right side and the left side".

**How to apply:** held in `SectionCard` / `SectionList` headers and the section-subheading guard test; shorten long sentences rather than letting them wrap.
