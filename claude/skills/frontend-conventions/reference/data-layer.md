# Reference: RTK Query Data Layer

Read this before adding any endpoint, mutation, or touching auth/refresh.

## One central API slice with silent reauth

`redux/api-slice.ts` is the only `createApi`. It carries the base query, the
Mutex-guarded token refresh, and the tag registry. Everything else injects into it.

```ts
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";
import { Mutex } from "async-mutex";
import { userLoggedIn, userLoggedOut } from "./auth/auth-slice";
import { apiSliceTags } from "../types/api";

const mutex = new Mutex(); // single in-flight refresh, no stampede

const baseQuery = fetchBaseQuery({
  baseUrl: `${process.env.NEXT_PUBLIC_SERVER_URI}/api/v1`,
  credentials: "include", // httpOnly auth cookies
});

const baseQueryWithReauth = async (args, api, extraOptions) => {
  let result = await baseQuery(args, api, extraOptions);
  if (result.error?.status === 401) {
    if (!mutex.isLocked()) {
      const release = await mutex.acquire();
      try {
        const refresh = await baseQuery({ url: "auth/refresh-token", method: "POST" }, api, extraOptions);
        if (refresh.data) {
          api.dispatch(userLoggedIn({ user: refresh.data.data }));
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
      query: (params) => ({ url: buildDonationsUrl(params), method: "GET" }),
      providesTags: ["Donations"],
    }),
    createDonation: builder.mutation<IDonationResponse, ICreateDonationInput>({
      query: (body) => ({ url: "/donations", method: "POST", body }),
      invalidatesTags: ["Donations", "DashboardStats"], // refresh dependent caches
    }),
  }),
});

export const { useGetDonationsQuery, useCreateDonationMutation } = donationsApi;
```

Rules:
- One `<feature>-api.ts` per resource; `injectEndpoints` keeps code-splitting clean.
- **Queries declare `providesTags`; mutations declare `invalidatesTags`** for every
  cache they affect. A mutation that doesn't invalidate is a bug.
- Request and response are typed from `types/` — never inline shapes.

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
const { data, isLoading, isError } = useGetDonationsQuery(params);

if (isLoading) return <DonationsTableSkeleton />;
if (isError) return <ErrorState onRetry={refetch} />;
if (!data?.data.length) return <EmptyState title="No donations yet" />;
return <DonationsTable rows={data.data} meta={data.meta} />;
```

Rules:
- Handle `isLoading` / `isError` / **empty** every time. Reuse `*Skeleton` components.
- Don't copy RTK Query data into local `useState`/Redux — read the cache directly;
  derive with `useMemo` if needed.

## Error → message helper

Standardize RTK Query errors into a user-facing string + toast:

```ts
export const extractApiErrorMessage = (error: unknown, fallback = "Something went wrong"): string => {
  if (error && typeof error === "object" && "data" in error) {
    const data = (error as { data?: { message?: string } }).data;
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
