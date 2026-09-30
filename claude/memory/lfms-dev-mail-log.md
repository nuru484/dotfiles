---
name: lfms-dev-mail-log
description: "LFMS dev sends no real email: MAIL_PROVIDER=log in lfms-api .env (30 Sep 2026); only switch to resend when the owner asks to test delivery"
metadata:
  type: feedback
---

Owner, 30 Sep 2026: builds and walks were sending real email through Resend and eating the daily limit.

**How to apply:** lfms-api `.env` (and any copied worktree `.env`) keeps `MAIL_PROVIDER=log`; the log provider writes mail to the log. Set it to `resend` only when the owner asks to test real delivery, and put it back after. Never copy a `.env` with `resend` into a new checkout.
