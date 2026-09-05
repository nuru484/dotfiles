---
name: deployment-urls
description: "Deployed URLs for the user's frontends/backends (repo -> domain mapping)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 6edaf17b-920a-4d9c-929d-cd6cb5a31977
  modified: 2026-07-20T20:29:48.173Z
---

Production domains for the user's projects (repo name does not obviously map to the domain):

- `~/mhp/website-frontend` (hereafter-ghana-website) -> https://www.hereafterghana.org (apex 307s to www)
- `~/mhp/dms-frontend` -> https://giving.hereafterghana.org (the "DMS" / donation-management app)
- MHP backends: https://api.hereafterghana.org and https://dms-api.hereafterghana.org
- `~/repos/khadys-kitchen-frontend` -> https://khadyskitchen.com (apex 308s to www)
- `~/repos/traveltrek/frontend` -> https://traveltrek.manuru.dev (monorepo: frontend/ + backend/)
- `~/repos/bethere-client` -> https://bethere.manuru.dev (Vite SPA); backend https://api.bethere.manuru.dev
- `~/repos/chosen-fintech` -> https://www.chosenfintech.org (backend was on Render for thecssuds, not this)

All hosted on Vercel. Push to `main` triggers redeploy. See [[traveltrek-upgrade]].
