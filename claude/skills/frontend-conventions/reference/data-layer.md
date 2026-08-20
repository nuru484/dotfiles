# Reference: RTK Query Data Layer

Read this before adding any endpoint, mutation, or touching auth/refresh.

## One central API slice with silent reauth

`redux/api-slice.ts` is the only `createApi`. It carries the base query, the
Mutex-guarded token refresh, and the tag registry. Everything else injects into it.

```ts
import {
  createApi,
  fetchBaseQuery,
  type BaseQueryFn,
  type FetchArgs,
  type FetchBaseQueryError,
} from "@reduxjs/toolkit/query/react";
import { Mutex } from "async-mutex";
import { PUBLIC_ENV } from "@/lib/env"; // typed env module - never raw process.env
import { userLoggedIn, userLoggedOut } from "./auth/auth-slice";
import { apiSliceTags } from "../types/api";
import type { IAuthRefreshResponse } from "@/types/auth.types";

const mutex = new Mutex(); // single in-flight refresh, no stampede

const baseQuery = fetchBaseQuery({
  baseUrl: `${PUBLIC_ENV.SERVER_URI}/api/v1`,
  credentials: "include", // httpOnly auth cookies
});

const baseQueryWithReauth: BaseQueryFn<string | FetchArgs, unknown, FetchBaseQueryError> =
  async (args, api, extraOptions) => {
    let result = await baseQuery(args, api, extraOptions);
    if (result.error?.status === 401) {
      if (!mutex.isLocked()) {
        const release = await mutex.acquire();
        try {
          const refresh = await baseQuery({ url: "auth/refresh-token", method: "POST" }, api, extraOptions);
          if (refresh.data) {
            const { data } = refresh.data as IAuthRefreshResponse; // { message, data: user }
            api.dispatch(userLoggedIn({ user: data }));
            result = await baseQuery(args, api, extraOptions); // retry original
          } else {
            api.dispatch(userLoggedOut());
          }
        } finally { release(); }
      } else {
        await mutex.waitForUnlock();
        result = await baseQuery(args, api, extraOptions); // retry after the refresh that won the lock
      }
    }
    return result;
  };

export const apiSlice = createApi({
  reducerPath: "api",
  baseQuery: baseQueryWithReauth,
  tagTypes: apiSliceTags,
  endpoints: () => ({}),
});
```

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
