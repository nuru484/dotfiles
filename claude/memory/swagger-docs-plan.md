---
name: swagger-docs-plan
description: "OpenAPI docs pattern used in bethere-server and traveltrek backend (both done Aug 2026) - split spec, boot merge, CI route-drift check"
metadata: 
  node_type: memory
  type: project
  originSessionId: f555d458-03f1-40a2-af20-05c051f700a6
  modified: 2026-08-04T21:21:55.193Z
---

Both backends are documented as of 2026-08-04. Reuse this shape for the next
one (dms-backend, website-backend, agritrade-backend).

- **bethere-server**: 90 endpoints, Swagger UI at `/api/docs`.
- **traveltrek/backend**: 102 endpoints, same.

The pattern:

- Spec lives in `docs/openapi/`, split one file per domain under `paths/` and
  `components/`, plus a root `openapi.yaml` holding only info/servers/tags/
  security. A loader merges them at boot, so every `$ref` stays internal. The
  merge throws on a duplicate path or component name rather than silently
  overwriting.
- Prefix each domain's new component names (`Booking*`, `Payment*`) so files
  written independently cannot collide.
- Declare the session cookie as the **global** `security` default and override
  with `security: []` on the public handful.
- `npm run docs:check` validates with `@readme/openapi-parser` and diffs the
  spec against the live Express route table. Wired into CI. It must
  `process.exit(0)` explicitly, or the open Prisma/Redis handles hang the
  process until CI times out.
- The global `helmet()` sets `script-src 'self'`, which blanks Swagger UI.
  Mount a second helmet with a relaxed `script-src` on the docs route only.
- Cookie auth makes the Authorize dialog useless. Point readers at the
  demo-login endpoint and set `swaggerOptions.withCredentials: true`.

Two traps specific to **Express 5** (traveltrek), both cost real time:

1. A mount path is compiled into a matcher closure and **the string is not
   retained**, so walking the finished router recovers `/tours/{id}` but never
   the `/api/v1` prefix. `app._router` is also now `app.router`, and
   `express-list-endpoints` v7 hits the same wall. The fix is to patch
   `use` before importing the app and record prefixes as they register.
   `use` is NOT on the router's immediate prototype (a router is a function);
   walk the chain to find who owns it.
2. Any Dockerfile that copies sources **selectively** will not ship
   `docs/`, and the loader refuses to boot without it. Check the Dockerfile
   whenever adding runtime-read data files; traveltrek has no CI job that
   builds the image, so nothing else would have caught it.

Related: [[traveltrek-upgrade]], [[deployment-urls]]
