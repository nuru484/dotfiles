---
name: auth-conventions
description: "Implement or change authentication, sessions, authorization, ownership, or tenant isolation in the Express/Next.js house stack. Use for identity and access behavior, not every page that happens to require login."
---

# Authentication and authorization

Preserve the project's established identity provider, session model, and onboarding
policy. The defaults below apply to new house-stack cookie-JWT authentication;
other projects should not migrate merely to match this skill.

## Select the affected reference

- Token issuance/refresh/logout: [reference/tokens.md](reference/tokens.md).
- Registration/login/reset/verification: [reference/flows.md](reference/flows.md).
- Next.js redirects and SSR identity: [reference/nextjs-protection.md](reference/nextjs-protection.md).
- Organization membership/isolation: [reference/tenancy.md](reference/tenancy.md).

Load only what the task changes. Team labels alone do not prove a product needs
multi-tenancy; establish actual data ownership and access boundaries first.

## Invariants

- Authenticate requests and authorize both actions and resources on the API. Filter
  resource access using the verified actor/tenant context, not body-supplied identity.
  UI redirects and role-gated layouts are convenience, not enforcement.
- Hash passwords with the project's approved algorithm. For new argon2id use the
  established minimum (19456 KiB, 2 iterations, parallelism 1), checking current
  guidance and measuring the deployment cost before choosing production parameters.
- House sessions use short-lived access tokens and rotating refresh tokens. Keep
  durations in validated config; store token hashes, not usable tokens. Restrict
  verification algorithms and claims. Check current account/role/session state where
  immediate revocation matters; JWT claims may outlive a role or password change.
- Centralize signing/persistence in createAndPersistTokens and cookie writes in
  CookieManager. issueAuthTokens is a post-commit convenience wrapper for login.
  Refresh rotation persists its rejection/revocation outcome before raising an error;
  never set cookies or send external messages inside a retryable transaction.
- Refresh reuse and simultaneous legitimate refresh need an explicit policy. A
  same-tab mutex does not synchronize browser tabs. Retain sufficient family history
  for the chosen revocation policy and test races against the actual database.
- Cookie SameSite/domain/path depend on deployment topology. Refresh/logout must
  receive the refresh cookie; browser cookies on an API host may be unavailable to
  Next.js SSR. Keep tokens out of script-readable storage. Use security-hardening
  for the CSRF boundary when changing cookie topology.
- Missing/invalid-token logout is idempotent. Clear cookies even if revocation fails,
  but do not claim server revocation succeeded. Keep API outages distinct from
  invalid credentials so transient 503/network failures do not log users out.
- Reset/invitation/verification tokens are expiring and atomically single-use.
  Password reset invalidates sessions according to the product's revocation policy.
  Use durable delivery when a committed auth change requires an email.

## Completion

For the changed behavior, exercise valid, malformed, expired, denied, revoked, and
cross-tenant cases as applicable. Rotation/reset work needs concurrency and rollback
checks, including no cookies before commit and persisted replay revocation. SSR work
needs expired-access renewal, API/refresh outages, safe callback targets, and no
redirect loops. Report test results and deployment/browser behavior not yet verified.
