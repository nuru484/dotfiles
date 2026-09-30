---
name: lfms-discuss-before-payments
description: LFMS Phase 11 (payments and gateways) must be discussed and planned with the owner before any implementation
metadata:
  type: feedback
---

Before implementing Phase 11 (payments and gateways) in LFMS, stop and
discuss the plan with the owner; do not start building it unasked.

**Why:** the owner said so on 28 September 2026 while M49 was finishing.
**How to apply:** when the queue reaches Phase 11, present the plan
(providers, intents, webhooks, settlement, screens) and wait for agreement.

**Owner's provider facts (2026-09-29), for that discussion:** Hubtel and Paystack for local payments, each with its own use cases, not interchangeable. Paystack takes USD and bank payments (Hubtel does neither). Hubtel's fees are capped, so above a certain amount it charges nothing more: the owner leans to Hubtel for large payments. Routing between them is a decision per payment (currency, method, amount), to be planned together.
