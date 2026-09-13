# Reference: RTK Query Data Layer

Read this before adding any endpoint, mutation, or touching auth/refresh.

## One central API slice with silent reauth

`redux/api-slice.ts` is the only `createApi`. It carries the base query, the
Coordinated token refresh, and the tag registry. Everything else injects into it.

Implement the reauth behavior from [reauth.md](reauth.md), including shared outcomes,
late 401 responses, auth endpoint exclusions, and outage handling. Use the project's
actual auth response schema. The API slice keeps refetchOnReconnect and optional
refetchOnFocus, with setupListeners in the store wiring.


Store wiring (`configureStore` + `apiSlice.middleware` + `StoreProvider`
placement in the root layout) is canonical in `project-scaffold` →
`reference/frontend-infra.md`. RTK Query silently stops refetching and
invalidating if the middleware is missing - copy the wiring, don't improvise.

Rules:
- Exactly **one** `createApi`. Never spin up a second.
- `tagTypes` come from a typed `apiSliceTags` list so tags can't drift.
- Auth refresh lives here only; features don't reimplement 401 handling.

## Feature endpoints via `injectEndpoints`

```ts
import { apiSlice } from "./api-slice";
import type { IDonationsResponse, IDonationQueryParams, IDonationResponse } from "@/types/donation.types";

export const donationsApi = apiSlice.injectEndpoints({
  endpoints: (builder) => ({
    getDonations: builder.query<IDonationsResponse, IDonationQueryParams | void>({
      query: (params) => ({ url: buildDonationsUrl("/donations", params), method: "GET" }),
      // id-level tags: lists invalidate precisely, detail pages stay cached
      providesTags: (result) =>
        result
          ? [
              ...result.data.map(({ id }) => ({ type: "Donations" as const, id })),
              { type: "Donations" as const, id: "LIST" },
            ]
          : [{ type: "Donations" as const, id: "LIST" }],
    }),
    getDonation: builder.query<IDonationResponse, string>({
      query: (id) => ({ url: `/donations/${id}`, method: "GET" }),
      providesTags: (_r, _e, id) => [{ type: "Donations", id }],
    }),
    createDonation: builder.mutation<IDonationResponse, ICreateDonationInput>({
      query: (body) => ({ url: "/donations", method: "POST", body }),
      invalidatesTags: [{ type: "Donations", id: "LIST" }, "DashboardStats"],
    }),
    updateDonation: builder.mutation<IDonationResponse, { id: string; body: IUpdateDonationInput }>({
      query: ({ id, body }) => ({ url: `/donations/${id}`, method: "PATCH", body }),
      // invalidate the one row AND the list (ordering/filters may change)
      invalidatesTags: (_r, _e, { id }) => [{ type: "Donations", id }, { type: "Donations", id: "LIST" }],
    }),
  }),
});

export const { useGetDonationsQuery, useGetDonationQuery, useCreateDonationMutation, useUpdateDonationMutation } = donationsApi;
```

Rules:
- One `<feature>-api.ts` per resource; `injectEndpoints` keeps code-splitting clean.
- **Queries declare `providesTags`; mutations declare `invalidatesTags`** for every
  cache they affect. A mutation that doesn't invalidate is a bug.
- **Use the id-level tag pattern above for every CRUD resource** (row tags +
  a `"LIST"` tag). Bare list tags (`providesTags: ["Donations"]`) over-invalidate
  every consumer on any mutation - acceptable only for tiny, rarely-mutated data.
- Request and response are typed from `types/` - never inline shapes.

## Typed query-string builders

```ts
const buildDateRangeUrl = (basePath: string, params: IDashboardQueryParams | void): string => {
  const q = new URLSearchParams();
  if (params?.preset) q.append("preset", params.preset);
  if (params?.startDate) q.append("startDate", params.startDate);
  if (params?.endDate) q.append("endDate", params.endDate);
  const qs = q.toString();
  return qs ? `${basePath}?${qs}` : basePath;
};
```

*Why:* one place to encode params, no `?a=${a}&b=${b}` drift, typed inputs.

## Consuming with required states

```ts
const { data, isLoading, isError, refetch } = useGetDonationsQuery(params);

if (isLoading) return <DonationsTableSkeleton />;
if (isError) return <ErrorState onRetry={refetch} />;
if (!data?.data.length) return <EmptyState title="No donations yet" />;
return <DonationsTable rows={data.data} meta={data.meta} />;
```

Rules:
- Handle `isLoading` / `isError` / **empty** every time. Reuse `*Skeleton` components.
- Don't copy RTK Query data into local `useState`/Redux - read the cache directly;
  derive with `useMemo` if needed.

## Error → message helper

Standardize RTK Query errors into a user-facing string + toast:

```ts
export const extractApiErrorMessage = (error: unknown, fallback = "Something went wrong"): string => {
  if (error && typeof error === "object" && "data" in error) {
    const data = (error as { data?: { message?: string; details?: { field: string; message: string }[] } }).data;
    // Validation errors carry per-field details (an array); surface the first one.
    const fieldError = data?.details?.[0];
    if (fieldError) return `${fieldError.field}: ${fieldError.message}`;
    if (data?.message) return data.message;
  }
  return fallback;
};

// usage
try {
  await createDonation(input).unwrap();
  toast.success("Donation recorded");
} catch (err) {
  toast.error(extractApiErrorMessage(err));
}
```

*Why:* one consistent failure UX; matches the backend's `{ message }` error envelope.

## Retry policy: queries may, mutations never

- **Queries MAY auto-retry transient failures** (network drop, 5xx). Wrap the
  base query once with RTK Query's `retry` helper, default OFF, and let query
  endpoints opt in: max 2 retries, exponential backoff (the helper's default).
  GET retries are safe because reads are idempotent; the cap keeps a hard
  outage from turning into a request storm.
- **Mutations NEVER auto-retry.** A timed-out mutation may have already been
  applied server-side, so an automatic retry is a double-submit risk
  (duplicate payments, duplicate rows). The user retries deliberately via the
  error toast (`extractApiErrorMessage` pattern above). Never put
  `maxRetries` on a mutation.

```ts
// redux/api-slice.ts: default OFF so mutations can never inherit retries
import { retry } from "@reduxjs/toolkit/query/react";

const baseQueryWithRetry = retry(baseQueryWithReauth, { maxRetries: 0 });

export const apiSlice = createApi({ baseQuery: baseQueryWithRetry, /* ... */ });
```

```ts
// a QUERY endpoint opts in; exponential backoff is built into the helper
getNotifications: builder.query<INotificationsResponse, void>({
  query: () => ({ url: "/notifications", method: "GET" }),
  extraOptions: { maxRetries: 2 },
  // ...
}),
```

## Optimistic updates: pessimistic by default

**Default is pessimistic:** the mutation settles, `invalidatesTags`
refetches, and the UI updates from the server's truth. That is the right
trade for almost everything.

Optimistic updates (`onQueryStarted` + `updateQueryData` + `patch.undo()` on
error + toast) are allowed ONLY for instant single-field toggles where the
client can compute the entire next state locally: a status switch,
favorite/unfavorite, read/unread. NEVER for money, anything that creates
rows (ids and timestamps are server-derived), or any write whose response
carries server-derived fields the UI needs.

Canonical example - the mark-notification-read toggle:

```ts
// redux/notifications-api.ts (add "Notifications" to apiSliceTags first)
markNotificationRead: builder.mutation<IApiResponse<null>, string>({ // 200 { message, data: null }
  query: (id) => ({ url: `/notifications/${id}/read`, method: "PATCH" }),
  async onQueryStarted(id, { dispatch, queryFulfilled }) {
    // Patch the cached list. The second argument (undefined here) must match
    // the cache key the consumer subscribed with; a parameterized query
    // patches each affected cache key.
    const patchResult = dispatch(
      notificationsApi.util.updateQueryData("getNotifications", undefined, (draft) => {
        const row = draft.data.find((n) => n.id === id);
        if (row && !row.readAt) {
          row.readAt = new Date().toISOString();
          if (draft.summary) {
            draft.summary.unreadCount = Math.max(0, draft.summary.unreadCount - 1);
          }
        }
      }),
    );
    try {
      await queryFulfilled;
    } catch {
      patchResult.undo(); // roll the cache back to the pre-toggle state
      toast.error("Could not mark the notification as read");
    }
  },
  // No invalidatesTags: an immediate refetch would defeat the optimism, and
  // the notifications poll (below) reconciles with the server anyway.
}),
```

## In-app notifications (bell + unread badge)

The UI half of in-app notifications. The backend contract (Notification
table, endpoints) and any SSE upgrade live in `saas-integrations`
`reference/realtime.md` - read that for anything transport-side; nothing
here duplicates it.

- **Bell in the app shell header** (client island): icon button + unread
  badge; the list opens as a dropdown on desktop and a bottom sheet on
  phones per mobile-first-ui's modal/sheet rules.
- **Data via a polled RTK Query query**, never a bespoke effect:

```ts
// consumer (bell component)
const { data } = useGetNotificationsQuery(undefined, {
  pollingInterval: 30_000, // the polling rung of the realtime ladder
  skipPollingIfUnfocused: true, // background tabs stop hitting the API
});
const notifications = data?.data ?? [];
const unreadCount = data?.summary?.unreadCount ?? 0;
```

- **unreadCount comes from the list envelope's `summary`**
  (`IApiListResponse<INotification, { unreadCount: number }>`), not a second
  endpoint and not a client-side count of the current page.
- **Mark-read is the optimistic toggle above.** Mark-all-read follows the
  same pattern: patch every row plus zero the summary, undo on error.
- Badge caps at `9+`; the icon-only button carries a real `aria-label`
  (a11y-seo rule):

```tsx
// components/notifications/notification-bell.tsx (trigger sketch)
<Button
  variant="ghost"
  size="icon"
  aria-label={`Notifications, ${unreadCount} unread`}
  className="relative"
>
  <Bell aria-hidden="true" />
  {unreadCount > 0 ? (
    <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] font-medium text-destructive-foreground">
      {unreadCount > 9 ? "9+" : unreadCount}
    </span>
  ) : null}
</Button>
```

If the realtime ladder upgrades the transport (SSE), only the transport
changes: the cache shape, the mark-read pattern, and this UI stay as-is.
