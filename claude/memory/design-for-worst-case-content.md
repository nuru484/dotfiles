---
name: design-for-worst-case-content
description: "UI must render gracefully with max-length content in every field, at every screen size"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 71a86592-a104-4508-9fae-b7a945aa9f01
---

The user's bar for "good UI/UX": assume every field holds its maximum allowed
content (per the Zod/DB limits — e.g. 150-char names, 255-char unbroken
emails, 1000-char notes) and the UI must still look intentional at every
width, from 280px up.

**Why:** "not something that will break if there's max content of its items"
— stated 2026-07-13 during the khadys-kitchen mobile overhaul, after real
overflow bugs from long emails.

**How to apply:** when building or reviewing UI, test with max-length data
(inject via SQL, revert after). Key techniques proven in khadys-kitchen:
`break-all` (not `break-words`) for unbroken tokens like emails — only
break-all shrinks min-content so flex/grid ancestors don't stretch;
length-adaptive type scale for display text (`detailTitleCls`,
`statValueCls` in `src/components/admin/ui.tsx`); truncate + tooltip in
dense list rows; never let the primary figure (money) truncate — meta text
gives way. See [[khadys-dev-testing-notes]].
