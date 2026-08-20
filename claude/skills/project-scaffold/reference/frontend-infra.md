# Reference: Frontend Infrastructure (canonical code)

Copy these modules into new Next.js App Router repos as-is, then extend for
the domain. Keep the exported names: `frontend-conventions` and
`api-contracts` refer to them by these names. All imports use the `@/` alias.
Every file below that uses hooks or the store is a client component; the
`"use client"` directives shown are load-bearing.

## Contents

1. [lib/env.ts (PUBLIC_ENV)](#1-libenvts-public_env)
2. [types/api.ts (apiSliceTags + envelope types)](#2-typesapits-apislicetags--envelope-types)
3. [redux/auth/auth-slice.ts](#3-reduxauthauth-slicets)
4. [redux/api-slice.ts (typed reauth base query)](#4-reduxapi-slicets-typed-reauth-base-query)
5. [redux/store.ts + hooks + StoreProvider + layout placement](#5-reduxstorets--hooks--storeprovider--layout-placement)
6. [Example feature api file (id-level tags)](#6-example-feature-api-file-id-level-tags)
7. [utils/api-error.ts (extractApiErrorMessage)](#7-utilsapi-errorts-extractapierrormessage)
8. [Shared UI states: skeletons, empty, error, toasts](#8-shared-ui-states-skeletons-empty-error-toasts)

---

## 1. lib/env.ts (PUBLIC_ENV)

Typed public env, mirroring the backend `ENV`: a missing `NEXT_PUBLIC_*` var
fails at build/module load with a named error, not as a silent `undefined`
baseUrl in the browser. Next.js inlines `NEXT_PUBLIC_*` only when referenced
literally, which is why the helper takes both the name and the value.

```ts
const required = (name: string, value: string | undefined): string => {
  if (!value) throw new Error(`Missing required public env: ${name}`);
  return value;
};

export const PUBLIC_ENV = {
  SERVER_URI: required("NEXT_PUBLIC_SERVER_URI", process.env.NEXT_PUBLIC_SERVER_URI),
} as const;
```

## 2. types/api.ts (apiSliceTags + envelope types)

One typed tag registry (so tags cannot drift between provides/invalidates)
and the envelope types that mirror the backend contract (see `api-contracts`).

```ts
/** Every cache tag the app uses. Add new resources here first. */
export const apiSliceTags = ["Auth", "Users", "Donations", "DashboardStats"] as const;

export type ApiSliceTag = (typeof apiSliceTags)[number];

/** Mirrors the backend list meta: { total, page, limit, totalPages }. */
export interface IApiMeta {
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

/** Mirrors the backend success envelope { message, data }. */
export interface IApiResponse<TData> {
  message: string;
  data: TData;
}

/** Mirrors the backend list envelope { message, data, meta, summary? }. */
export interface IApiListResponse<TItem, TSummary = undefined> {
  message: string;
  data: TItem[];
  meta: IApiMeta;
  summary?: TSummary;
}

/** Mirrors the backend error envelope produced by the central errorHandler. */
export interface IApiErrorEnvelope {
  status: "error";
  message: string;
  code?: string;
  details?: { field: string; message: string }[];
}
```

Feature response types build on these in `types/<feature>.types.ts`, e.g.
`export type IDonationsResponse = IApiListResponse<IDonation, IDonationSummary>;`.
A minimal `types/auth.types.ts` for the slices below:

```ts
import type { IApiResponse } from "./api";

export interface IUser {
  id: string;
  email: string;
  fullName: string;
  role: string;
}

export type IAuthResponse = IApiResponse<IUser>;
```

## 3. redux/auth/auth-slice.ts

Client-side session mirror. `loading` starts true so guards render a skeleton
instead of flashing a logged-out state before the initial "who am I" check;
`authChecked` clears it when that check resolves without a user.

```ts
import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type { IUser } from "@/types/auth.types";

interface AuthState {
  user: IUser | null;
  isAuthenticated: boolean;
  loading: boolean;
}

const initialState: AuthState = {
  user: null,
  isAuthenticated: false,
  loading: true,
};

const authSlice = createSlice({
  name: "auth",
  initialState,
  reducers: {
    userLoggedIn: (state, action: PayloadAction<{ user: IUser }>) => {
      state.user = action.payload.user;
      state.isAuthenticated = true;
      state.loading = false;
    },
    userLoggedOut: (state) => {
      state.user = null;
      state.isAuthenticated = false;
      state.loading = false;
    },
    authChecked: (state) => {
      state.loading = false;
    },
  },
});

export const { userLoggedIn, userLoggedOut, authChecked } = authSlice.actions;
export default authSlice.reducer;
```

## 4. redux/api-slice.ts (typed reauth base query)

The ONLY `createApi` in the app. It owns the base query (httpOnly cookie
auth via `credentials: "include"`), the Mutex-guarded silent token refresh
(one in-flight refresh, no stampede; waiters retry after the winner
finishes), and the tag registry. Features inject endpoints into it; nothing
reimplements 401 handling.

```ts
import { createApi, fetchBaseQuery } from "@reduxjs/toolkit/query/react";
import type { BaseQueryFn, FetchArgs, FetchBaseQueryError } from "@reduxjs/toolkit/query";
import { Mutex } from "async-mutex";
import { PUBLIC_ENV } from "@/lib/env";
import { apiSliceTags } from "@/types/api";
import type { IAuthResponse } from "@/types/auth.types";
import { userLoggedIn, userLoggedOut } from "./auth/auth-slice";

const mutex = new Mutex();

const baseQuery = fetchBaseQuery({
  baseUrl: `${PUBLIC_ENV.SERVER_URI}/api/v1`,
  credentials: "include", // httpOnly auth cookies
});

const baseQueryWithReauth: BaseQueryFn<
  string | FetchArgs,
  unknown,
  FetchBaseQueryError
> = async (args, api, extraOptions) => {
  await mutex.waitForUnlock(); // never race a refresh already in flight
  let result = await baseQuery(args, api, extraOptions);

  if (result.error?.status === 401) {
    if (!mutex.isLocked()) {
      const release = await mutex.acquire();
      try {
        const refresh = await baseQuery(
          { url: "auth/refresh-token", method: "POST" },
          api,
          extraOptions,
        );
        if (refresh.data) {
          const { data: user } = refresh.data as IAuthResponse;
          api.dispatch(userLoggedIn({ user }));
          result = await baseQuery(args, api, extraOptions); // retry original
        } else {
          api.dispatch(userLoggedOut());
        }
      } finally {
        release();
      }
    } else {
      // Another request won the lock; wait for its refresh, then retry.
      await mutex.waitForUnlock();
      result = await baseQuery(args, api, extraOptions);
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

## 5. redux/store.ts + hooks + StoreProvider + layout placement

Per the Redux Next.js guidance, create the store in a factory and instantiate
it once per browser session inside a client provider with `useRef`. A
module-level store would be shared across requests during SSR and leak state
between users.

```ts
// redux/store.ts
import { configureStore } from "@reduxjs/toolkit";
import { setupListeners } from "@reduxjs/toolkit/query";
import { apiSlice } from "./api-slice";
import authReducer from "./auth/auth-slice";

export const makeStore = () => {
  const store = configureStore({
    reducer: {
      [apiSlice.reducerPath]: apiSlice.reducer,
      auth: authReducer,
    },
    middleware: (getDefaultMiddleware) =>
      getDefaultMiddleware().concat(apiSlice.middleware),
  });
  // refetchOnFocus / refetchOnReconnect support
  setupListeners(store.dispatch);
  return store;
};

export type AppStore = ReturnType<typeof makeStore>;
export type RootState = ReturnType<AppStore["getState"]>;
export type AppDispatch = AppStore["dispatch"];
```

```ts
// redux/hooks.ts - always use these instead of the raw react-redux hooks
import { useDispatch, useSelector } from "react-redux";
import type { AppDispatch, RootState } from "./store";

export const useAppDispatch = useDispatch.withTypes<AppDispatch>();
export const useAppSelector = useSelector.withTypes<RootState>();
```

```tsx
// components/providers/store-provider.tsx
"use client";

import { useRef } from "react";
import { Provider } from "react-redux";
import { makeStore, type AppStore } from "@/redux/store";

export function StoreProvider({ children }: { children: React.ReactNode }) {
  const storeRef = useRef<AppStore | null>(null);
  if (!storeRef.current) {
    storeRef.current = makeStore(); // create exactly once per client
  }
  return <Provider store={storeRef.current}>{children}</Provider>;
}
```

Placement: the provider wraps the app in the root layout, which itself stays
a Server Component (wrapping children in a client provider does not make the
page tree client-side).

```tsx
// app/layout.tsx
import { StoreProvider } from "@/components/providers/store-provider";
import { Toaster } from "@/components/ui/sonner";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <StoreProvider>{children}</StoreProvider>
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
```

## 6. Example feature api file (id-level tags)

One `redux/<feature>-api.ts` per resource, injecting into the central slice.
Prefer id-level tags: a single-item update then invalidates only that id plus
the LIST tag, instead of refetching every query that touches the type. (The
whole-type shorthand `providesTags: ["Donations"]` from the conventions
reference is acceptable for small read-mostly features; this is the canonical
full form.)

```ts
// redux/donations-api.ts
import { apiSlice } from "./api-slice";
import type {
  ICreateDonationInput,
  IDonationQueryParams,
  IDonationResponse,
  IDonationsResponse,
  IUpdateDonationInput,
} from "@/types/donation.types";

/** Typed URL builder: one place to encode params, no string drift. */
const buildDonationsUrl = (params: IDonationQueryParams | void): string => {
  const q = new URLSearchParams();
  if (params?.page) q.append("page", String(params.page));
  if (params?.limit) q.append("limit", String(params.limit));
  if (params?.status) q.append("status", params.status);
  const qs = q.toString();
  return qs ? `/donations?${qs}` : "/donations";
};

export const donationsApi = apiSlice.injectEndpoints({
  endpoints: (builder) => ({
    getDonations: builder.query<IDonationsResponse, IDonationQueryParams | void>({
      query: (params) => ({ url: buildDonationsUrl(params), method: "GET" }),
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
      providesTags: (_result, _error, id) => [{ type: "Donations" as const, id }],
    }),
    createDonation: builder.mutation<IDonationResponse, ICreateDonationInput>({
      query: (body) => ({ url: "/donations", method: "POST", body }),
      // New row: refresh lists and dependent aggregates, not individual ids.
      invalidatesTags: [{ type: "Donations", id: "LIST" }, "DashboardStats"],
    }),
    updateDonation: builder.mutation<
      IDonationResponse,
      { id: string; body: IUpdateDonationInput }
    >({
      query: ({ id, body }) => ({ url: `/donations/${id}`, method: "PATCH", body }),
      // Touched row + lists that may order/filter on the changed fields.
      invalidatesTags: (_result, _error, { id }) => [
        { type: "Donations", id },
        { type: "Donations", id: "LIST" },
      ],
    }),
    deleteDonation: builder.mutation<IDonationResponse, string>({
      query: (id) => ({ url: `/donations/${id}`, method: "DELETE" }),
      invalidatesTags: (_result, _error, id) => [
        { type: "Donations", id },
        { type: "Donations", id: "LIST" },
        "DashboardStats",
      ],
    }),
  }),
});

export const {
  useGetDonationsQuery,
  useGetDonationQuery,
  useCreateDonationMutation,
  useUpdateDonationMutation,
  useDeleteDonationMutation,
} = donationsApi;
```

## 7. utils/api-error.ts (extractApiErrorMessage)

One RTK-Query-error to user-message helper, so every mutation surfaces
failures the same way. It reads the backend error envelope
`{ status: "error", message, code?, details? }` and flattens validation
details (`[{ field, message }]`, produced by the backend for
`VALIDATION_ERROR`) into a readable string.

```ts
import type { IApiErrorEnvelope } from "@/types/api";

const isErrorEnvelope = (data: unknown): data is IApiErrorEnvelope =>
  typeof data === "object" &&
  data !== null &&
  "message" in data &&
  typeof (data as { message?: unknown }).message === "string";

export const extractApiErrorMessage = (
  error: unknown,
  fallback = "Something went wrong",
): string => {
  if (error && typeof error === "object" && "data" in error) {
    const data = (error as { data?: unknown }).data;
    if (isErrorEnvelope(data)) {
      if (Array.isArray(data.details) && data.details.length > 0) {
        return data.details
          .map((issue) =>
            issue.field ? `${issue.field}: ${issue.message}` : issue.message,
          )
          .join("; ");
      }
      if (data.message) return data.message;
    }
  }
  return fallback;
};
```

## 8. Shared UI states: skeletons, empty, error, toasts

Every query consumer handles loading, error, and empty explicitly:

```tsx
const { data, isLoading, isError, refetch } = useGetDonationsQuery(params);

if (isLoading) return <DonationsTableSkeleton />;
if (isError) return <ErrorState onRetry={() => refetch()} />;
if (!data?.data.length) return <EmptyState title="No donations yet" />;
return <DonationsTable rows={data.data} meta={data.meta} />;
```

### components/shared/skeletons.tsx

Convention: one `<Component>Skeleton` per real component, MIRRORING ITS
LAYOUT (same rows, heights, and grid) so nothing shifts when data arrives.
Build them from the shadcn `Skeleton` primitive; co-locate large
feature-specific ones next to the feature component instead of here.

```tsx
import { Skeleton } from "@/components/ui/skeleton";

export function DonationsTableSkeleton() {
  return (
    <div className="space-y-2">
      <Skeleton className="h-10 w-full" /> {/* header row */}
      {Array.from({ length: 5 }).map((_, i) => (
        <Skeleton key={i} className="h-12 w-full" /> // one per expected row
      ))}
    </div>
  );
}
```

### components/shared/empty-state.tsx

Server-safe (no handlers), so lists rendered on the server can use it too.

```tsx
interface EmptyStateProps {
  title: string;
  description?: string;
  action?: React.ReactNode;
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed p-10 text-center">
      <p className="font-medium">{title}</p>
      {description ? (
        <p className="text-sm text-muted-foreground">{description}</p>
      ) : null}
      {action}
    </div>
  );
}
```

### components/shared/error-state.tsx

```tsx
"use client";

import { Button } from "@/components/ui/button";

interface ErrorStateProps {
  message?: string;
  onRetry?: () => void;
}

export function ErrorState({
  message = "Something went wrong. Please try again.",
  onRetry,
}: ErrorStateProps) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-destructive/30 p-10 text-center">
      <p className="text-sm text-muted-foreground">{message}</p>
      {onRetry ? (
        <Button variant="outline" onClick={onRetry}>
          Try again
        </Button>
      ) : null}
    </div>
  );
}
```

### Toast wiring (sonner)

`npx shadcn@latest add sonner` provides `components/ui/sonner`; mount its
`<Toaster />` once in `app/layout.tsx` (shown in section 5). Mutations then
follow one pattern everywhere, never swallowing errors:

```ts
import { toast } from "sonner";
import { extractApiErrorMessage } from "@/utils/api-error";

try {
  await createDonation(values).unwrap();
  toast.success("Donation recorded");
} catch (err) {
  toast.error(extractApiErrorMessage(err));
}
```
