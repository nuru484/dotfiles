# Silent refresh without false logout

Implement this state machine in the existing API base query. Use the installed
RTK Query types and the actual auth response schema. This specifies behavior rather
than a version-independent drop-in module.

## State ownership

Keep the in-flight refresh promise and its outcome scoped to the browser session
or store. Do not share user/session state across server requests. A module singleton
may be appropriate in a browser-only app, not in an SSR worker serving many users.
Track a monotonically increasing completed-refresh generation and the last outcome
so late 401 responses can observe a refresh that already finished.

## Request sequence

1. Exclude login/register/reset/logout and refresh endpoints from automatic reauth;
   their failures must reach their own flow, not recursively request renewal.
2. For a protected request, await any active refresh. If that refresh failed,
   propagate its outcome rather than issuing requests known to fail. Snapshot the
   generation immediately before issuing the original request.
3. If the original response is not 401, return it. Never renew on 403 or a 5xx.
4. On 401, if a refresh completed since the request began, use that recorded
   outcome. Otherwise join the in-flight refresh or start one shared promise.
5. The refresh call uses the raw transport, not the reauth wrapper. Validate its
   payload against the real auth schema. Record the result and advance the generation
   before resolving waiters; clear only the completed in-flight promise.
6. Success updates identity once and retries each original request at most once.
   A repeated 401 does not start an unbounded loop.
7. A definitive refresh 401 clears identity and protected cached data through the
   project's logout/reset path. A 503, network failure, or malformed success response
   becomes a recoverable error, preserves identity, and reaches all waiting requests.
   A user-initiated retry can start a new attempt after the failure.

Replaying a mutation after a 401 is safe only if the API guarantees auth rejection
before side effects. Timeouts/5xx must not automatically replay uncertain mutations
without an idempotency/reconciliation contract. Cross-tab refresh still needs the
server's documented concurrency policy; one promise synchronizes only one runtime.

## Verification

Use controllable transport responses and an isolated store to test: concurrent 401s
with one refresh, late 401 after refresh completion, refresh 503 reaching all waiters
without logout, malformed success, auth endpoint exclusion, final refresh 401 cache
clearing, one retry per request, and later manual retry after failure. Exercise the
server rotation policy separately with a real database. Do not claim browser cookie
compatibility from these transport tests.
