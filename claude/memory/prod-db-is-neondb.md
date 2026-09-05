---
name: prod-db-is-neondb
description: "dms-backend production DB is the Neon \"neondb\" database, not \"dms_test\""
metadata: 
  node_type: memory
  type: project
  originSessionId: 019dc29a-b928-4737-bc69-fd5f7133277e
---

For **dms-backend**, the production database the deployed server (AWS EC2
`ip-172-31-17-17`) connects to is the Neon database named **`neondb`** — NOT
`dms_test`. `dms_test` is a separate test/staging DB on the same Neon host.

**Why:** I once ran `prisma migrate deploy` + `migrate status` against `dms_test`
(it reported "up to date"), but production kept throwing `P2021 table does not
exist` / `P2022 column Donor.donorCode does not exist` because the real prod DB
(`neondb`) never got the migrations.

**How to apply:** When migrating prod, target the URL ending in `/neondb`, and
confirm the datasource line in the command output names database `"neondb"`
before trusting a "schema is up to date" result. Never store the connection
string here — the user provides it each time.
