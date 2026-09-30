---
name: enterprise-complete-linked-entities
description: "LFMS owner wants every feature built enterprise-complete now (no \"later\" scoping) and every entity reference a real, navigable relationship system-wide"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 5087a1d5-35c4-47a4-8722-4e5c09cfd52b
  modified: 2026-09-29T04:23:00.611Z
---

Build LFMS features to full enterprise scope in one go; never trim a spec to a minimal "foundation" and defer the rest. Every reference between entities (bank account, office, court/judge, tax, ledger account, person, matter...) must be a real relationship: one canonical record, shown by its name everywhere, linking to its record page, with the record page summarising and linking what hangs off it (history, balances, related lists). No text stand-ins like "GCB ending 4567", no matching by fund/currency filters where a foreign key belongs.

**Why:** 29 Sep 2026 the owner rejected a slim offices plan as "filler" and called out bank accounts shown as "X ending 342" in Banking lists: "it should be connected... not some quick weekend project".

**How to apply:** when planning LFMS work, scope from the full domain (e.g. offices: staff office, staff ids, office scope permissions, matter transfer history, office summaries); overrides ponytail-style minimalism for scope (not for code style). Audit relationships both directions. Related: [[every-list-searchable]], [[lfms-fixes-2026-09-29]].
