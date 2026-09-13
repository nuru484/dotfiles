# Next.js page and route protection

Read installed Next.js docs before changing request handling. Next.js 16 uses
proxy.ts with a proxy export; older releases may require middleware.ts. Proxy
redirects are optional. The Express API remains the authorization boundary.

## Session state and renewal

Distinguish these outcomes: authenticated, unauthenticated, forbidden, and temporarily
unavailable. A missing access cookie or API 401 may still have a valid refresh
session. Do not redirect unconditionally to login before allowing the existing
renewal path to run. A 403 is a permission outcome; a 503/network error needs an
error/retry state and must not clear identity or cookies.

Server Component rendering cannot set the browser's refresh cookies. A typical
house-stack renewal path lets a client boundary POST to the API refresh endpoint,
then refresh the server-rendered route on success. On definitive refresh 401, route
to login; on transient errors, show retry UI. Bound attempts and prevent loops.
Use a validated local callback path, not arbitrary external redirect targets.

Check cookie topology first. A refresh cookie scoped to /api/v1/auth will not arrive
with /dashboard. Host-only API cookies will not arrive at a separate Next.js host.
Do not pretend cookies() can read cookies the browser did not send. Preserve the
project's same-origin or compatible-domain architecture, or report the required
architecture change rather than inventing a working SSR session.

## Server-to-API lookup

Forward only the required cookie to the configured trusted API; do not forward the
entire cookie jar. Disable redirects or validate every destination before forwarding
authentication. Await cookies() on versions that require it, use no-store for session
fetches, and use React.cache only for request-local deduplication.

```ts
import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { PUBLIC_ENV } from "@/lib/env";
import type { IAuthResponse } from "@/types/auth.types";

export const getSession = cache(async () => {
  const access = (await cookies()).get("access_token");
  if (!access) return null; // caller must still allow the configured renewal path
  const res = await fetch(`${PUBLIC_ENV.SERVER_URI}/api/v1/auth/me`, {
    headers: { Cookie: `access_token=${encodeURIComponent(access.value)}` },
    cache: "no-store",
    redirect: "error",
  });
  if (res.status === 401) return null;
  if (!res.ok) throw new Error(`Session lookup failed (${res.status})`);
  return ((await res.json()) as IAuthResponse).data;
});
```

Adapt error typing and response validation to the API contract. Keep forbidden and
unavailable results distinguishable in the page/error boundary. A type assertion
alone does not validate an external response.

Layouts do not necessarily rerun on navigation between their children. Sensitive
pages must obtain current authorized data from the API rather than trusting a
previous layout result. Client identity comes from the auth API response; do not
decode JWTs in the browser to decide authoritative access.

## Required checks

Exercise missing/expired access with valid refresh, definitive refresh rejection,
/me and refresh 503/network failure, role denial, unsafe callback URLs, and redirect
loops. Static inspection is not proof that browser cookies work across the deployed
origins; record that part for the user's rendered review.
