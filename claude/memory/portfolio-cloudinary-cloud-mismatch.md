---
name: portfolio-cloudinary-cloud-mismatch
description: The portfolio repo's local .env Cloudinary account differs from the one holding the older project images
metadata:
  type: project
---

In `~/repos/portfolio`, the local `.env` holds Cloudinary cloud `dam0swaaq`, but
the project/post images seeded before 2026-08-23 live on cloud `dnpvi7cyq`, whose
credentials are not in the repo. Both render fine because `next.config.ts` allows
any `res.cloudinary.com` path, but deleting an older image from the dashboard
silently no-ops (`deleteImage` swallows the cloud_name mismatch).

**Why:** picking the wrong cloud when uploading leaves orphaned assets that the
admin can never clean up.

**How to apply:** upload new portfolio media to `dam0swaaq` (the configured one)
unless the production Vercel env is confirmed to use `dnpvi7cyq`; if it does,
get those credentials before touching image deletion.
