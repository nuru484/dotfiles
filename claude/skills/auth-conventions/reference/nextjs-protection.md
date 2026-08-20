# Reference: Next.js Page and Route Protection

Read this before touching middleware.ts, a protected page, a role-gated layout, or
any Server Component that calls the Express API. The model is defense in layers with
one rule above all: **the Express API is the enforcement point**. authenticateJWT,
authorize, and service-level ownership checks decide what data moves. Everything in
this file is UX on top: fast redirects and correct first paints, never the security
boundary.

## Contents
- middleware.ts (fast redirect)
- getSession() server helper (cookie forwarding + React.cache)
- Role-gated layout
- Client-side state rules

## middleware.ts (fast redirect, not the boundary)

Middleware runs before rendering and checks only that the access cookie EXISTS. It
cannot be the boundary: an expired or forged cookie passes this check, and that is
fine, because the server-side getSession() call and the API itself reject it. The
value of middleware is bouncing obviously-logged-out users to /login before any
rendering work, with a callbackUrl so they land back where they aimed.

```ts
// middleware.ts (project root)
import { NextResponse, type NextRequest } from "next/server";

const ACCESS_COOKIE = "access_token";

export function middleware(req: NextRequest) {
  if (req.cookies.has(ACCESS_COOKIE)) return NextResponse.next();

  const { pathname, search } = req.nextUrl;
  const loginUrl = new URL("/login", req.url);
  loginUrl.searchParams.set("callbackUrl", pathname + search);
  return NextResponse.redirect(loginUrl);
}

export const config = {
  matcher: ["/dashboard/:path*", "/settings/:path*", "/admin/:path*"],
};
```

Keep the matcher in sync with the protected route groups. If the JWT secret is
shared with the Next app you may additionally verify the signature with `jose`
(Edge-compatible), but that upgrades the UX check, it still does not replace
server-side verification.

## getSession(): the SSR-to-API recipe

A Server Component fetch carries NO browser cookies on its own: the browser sent its
cookies to the Next server, not to your Express API. Reading `cookies()` from
`next/headers` and forwarding them in the `Cookie` header is the ONLY way SSR can
call the cookie-authed API. `React.cache` dedupes the call per request, so layout,
page, and components can all call getSession() and only one /auth/me round trip
happens per render.

```ts
// lib/get-session.ts
import "server-only";
import { cache } from "react";
import { cookies } from "next/headers";
import { PUBLIC_ENV } from "@/lib/env";

export interface SessionUser {
  id: string;
  fullName: string;
  email: string;
  role: "USER" | "ADMIN";
  emailVerifiedAt: string | null; // sensitive features may check this
}

// The API's success envelope is { message, data } with the safe user object
// directly at the data root (IAuthResponse = IApiResponse<IUser>)
interface MeResponse {
  message: string;
  data: SessionUser;
}

export const getSession = cache(async (): Promise<SessionUser | null> => {
  const cookieStore = await cookies();

  const res = await fetch(`${PUBLIC_ENV.SERVER_URI}/api/v1/auth/me`, {
    headers: { Cookie: cookieStore.toString() },
    cache: "no-store", // auth state must never be served stale from the fetch cache
  });

  if (!res.ok) return null; // 401 from the API is the real verdict
  const body = (await res.json()) as MeResponse;
  return body.data;
});
```

Use the same pattern for any other SSR call to the API: forward
`cookieStore.toString()` as the `Cookie` header. Note: getSession() cannot refresh
an expired access token during SSR (a Server Component render cannot reliably set
cookies); a null session here simply redirects to login or renders the
logged-out state, and the client-side silent refresh recovers the session.

## Role-gated layout

Gate whole sections in a layout so every page under it inherits the check. Redirect,
do not render a "forbidden" shell around admin routes, so their existence leaks
nothing to non-admins.

```tsx
// app/admin/layout.tsx
import { redirect } from "next/navigation";
import { getSession } from "@/lib/get-session";

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const user = await getSession();

  if (!user) redirect("/login?callbackUrl=/admin");
  if (user.role !== "ADMIN") redirect("/dashboard");

  return <>{children}</>;
}
```

Two caveats that keep this honest:
- Layouts do not re-run on soft navigation between their children, so pages that
  render sensitive data must also call getSession() (free, thanks to React.cache)
  or simply rely on their API calls returning 401/403.
- The layout hides pages; it does not protect data. The API's authorize(...roles)
  middleware and service ownership checks remain the enforcement point for every
  byte an admin page fetches.

## Client-side state rules

- Authenticated state lives in the Redux auth slice, fed by the refresh flow: the
  RTK Query base query holds a Mutex so concurrent 401s trigger exactly one silent
  refresh, then retry the original requests.
- Never store tokens or user identity in localStorage or sessionStorage. The
  httpOnly cookies are the source of truth; readable storage would recreate the
  XSS theft surface those cookies exist to remove.
- On refresh failure (refresh token expired or revoked), the base query dispatches
  a logout action to clear the auth slice and the UI routes to /login. No client
  code ever inspects or decodes the JWT: the /auth/me response is the identity.
