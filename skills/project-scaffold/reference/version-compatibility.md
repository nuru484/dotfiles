# Version compatibility before using recipes

Read the project's package manifest, lockfile, generated imports, and installed
package types/docs. Keep its supported versions. For new projects verify stable
compatible releases; never combine latest packages with older recipe APIs blindly.

## Prisma

The older backend examples use Prisma 6-style @prisma/client imports and
`datasourceUrl`. For Prisma 7, configure CLI datasource/seed in prisma.config.ts,
use the configured generated-client output, and construct the client with the
appropriate driver adapter (PostgreSQL: PrismaPg from @prisma/adapter-pg).
Run generation explicitly after schema changes; do not assume migrate dev seeds
or generates the client. Adapt every Prisma type/import to the chosen generator.
For a different major, consult its migration/client docs before using these recipes.
Do not change an existing app's ORM major as part of an unrelated scaffold task.

Source: [Prisma 7 upgrade guidance](https://www.prisma.io/docs/guides/upgrade-prisma-orm/v7).

## Next.js / React

Read node_modules/next/dist/docs when available. Next.js 16 uses proxy.ts with a
proxy export; middleware.ts belongs to older versions. Proxy is an optional early
redirect, never the authorization boundary. Await request APIs where the installed
version requires it. Server Components may render Client Components; context
providers/consumers belong in the client graph, not all uses of React.use.
Check the installed React version before adopting version-specific hooks.

Sources: [Proxy](https://nextjs.org/docs/app/getting-started/proxy),
[Server and Client Components](https://nextjs.org/docs/app/getting-started/server-and-client-components).

## Queue and platform examples

backend-infra.md's queue API targets pg-boss 10; verify installed exports, batch
handler shape, queue creation, and transaction integration before adapting it.
A normal boss.send call is not automatically part of a Prisma transaction.
Validate deployment script names against package.json; production never runs
watch-mode entrypoints. Match database service versions to production requirements.
