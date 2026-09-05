---
name: madrasa-donor-seed-2026-07
description: "Madrasa donor Excel seeded into dms-backend prod (Neon) on 2026-07-22 - placeholder phone convention, skipped codes, known dup"
metadata: 
  node_type: memory
  type: project
  originSessionId: d5848f96-f8c5-45f2-92f6-1d9c2ff29c6a
  modified: 2026-07-22T13:04:04.684Z
---

Seeded 230 madrasa donors (codes MSP1-MSP234, canonical no-hyphen form) from
"MADRASA DONOR DATA.xlsx" into the [[prod-db-is-neondb]] production DB on
2026-07-22: 116 new donors, 114 existing donors matched by phone and updated
(name/email overwritten, code + Madrasa Sponsors category assigned).

**Why:** the sheet had data problems the admin may ask about later.

**How to apply:**
- 30 donors have placeholder phones `+233000000<code#>` (sheet had no/invalid
  phone). Admins should replace them via the madrasa donor edit form. Bulk SMS
  to them just fails harmlessly.
- Codes MSP82, MSP90, MSP94, MSP165 were skipped - sheet rows were blank except
  the code (no name/phone/email). Numbers stay reserved; admins can create them
  manually.
- MSP21 (Yakubu Ali) and MSP211 (Yakub) both listed +19126068410 in the sheet;
  MSP21 kept the real phone, MSP211 got a placeholder - likely the same person
  with two codes, needs admin resolution.
- sponsoredStudents left null where sheet was junk ("m", "_", "random", empty):
  MSP34, MSP193, MSP197, MSP199, MSP212 (+ rows with none). "10+20"/"3+7" were
  summed (MSP89=30, MSP171=10).
- MSP300 (user's test code on their own donor record, which holds 89 real
  donations + 16 subscriptions) was cleared on 2026-07-22 at the user's request;
  the donor record itself was kept. Next auto-generated code is MSP235.
