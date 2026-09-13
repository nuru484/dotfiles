# Reference: Components, Rendering & Forms

Read this before creating a page/component or a form.

## Server Components by default

A component is a Server Component unless it needs the browser. Reach for
`"use client"` only when the file uses: `useState`/`useReducer`, `useEffect`,
event handlers, RTK Query hooks, refs, or browser APIs.

```tsx
// app/donations/page.tsx  - Server Component (no "use client")
export const metadata = { title: "Donations" };

export default function DonationsPage() {
  return (
    <section>
      <PageHeader title="Donations" />     {/* server */}
      <DonationsTable />                    {/* client island - see below */}
    </section>
  );
}
```

```tsx
// components/donations/data-table/donations-table.tsx
"use client"; // needs RTK Query + interactivity
export function DonationsTable() {
  const { data, isLoading, isError } = useGetDonationsQuery();
  // ...states...
}
```

Rules:
- Don't lift a whole page to the client for one interactive widget - isolate the
  island.
- Public/marketing/SEO pages stay server-rendered: real `metadata`, no client-only
  data gate hiding content from crawlers.
- Static content comes from `static-data/` or props, rendered on the server.

## Server Components fetching from the Express API

Server Components call the same `/api/v1` contract, directly with `fetch`.
Two things make it work:

1. **Cookie forwarding.** The API is authenticated by httpOnly cookies which
   do NOT accompany server-side fetches automatically - forward them:

```ts
// lib/server-api.ts (server-only)
import { cookies } from "next/headers";
import { PUBLIC_ENV } from "@/lib/env";

export const serverFetch = async <T>(path: string, init?: RequestInit): Promise<T> => {
  const cookieHeader = (await cookies()).toString();
  const res = await fetch(`${PUBLIC_ENV.SERVER_URI}/api/v1${path}`, {
    ...init,
    headers: { ...init?.headers, cookie: cookieHeader },
    cache: "no-store", // authed data: never cache across users
  });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { message?: string } | null;
    throw new Error(body?.message ?? `API ${res.status} on ${path}`);
  }
  return res.json() as Promise<T>;
};
```

2. **Caching is explicit.** `fetch` in Server Components is uncached by
   default in current Next.js. Authenticated/per-user data stays
   `cache: "no-store"` (as above). Public data (marketing pages, public
   lists) may opt into time-based revalidation:
   `fetch(url, { next: { revalidate: 300 } })`. Decide per call site; never
   revalidate authed responses.

Reads may come from either half (Server Component via `serverFetch` for
first-paint/SEO, RTK Query in islands for interactive data); ALL mutations go
through RTK Query. Auth/session helpers (`getSession`, route protection) live
in `auth-conventions` → `reference/nextjs-protection.md`.

## Component organisation

- Group by feature: `components/<feature>/...`, with `data-table/`, `detail/`,
  `forms/`, etc. Shared primitives in `components/ui/` (shadcn).
- One component concern per file; co-locate a feature's small helpers with it.
- Compose classes with `cn()` (clsx + tailwind-merge); variants with `cva`.

## Forms: react-hook-form + Zod

Schema lives in `validations/` and mirrors the backend contract.

```ts
// validations/donation-validation.ts
import { z } from "zod";
import { SUPPORTED_CURRENCIES } from "@/static-data/currencies"; // as const tuple

// Mirrors backend createDonation validation: amount > 0, currency required.
export const donationFormSchema = z.object({
  donorName: z.string().min(1, "Name is required").max(255).trim(),
  // HTML inputs yield STRINGS: coerce before validating, or every numeric
  // field fails with "expected number, received string".
  amount: z.coerce.number().positive("Amount must be greater than 0"),
  currency: z.enum(SUPPORTED_CURRENCIES),
});
export type DonationFormValues = z.infer<typeof donationFormSchema>;
```

Money note: the form collects major units for humans; convert to integer
minor units at the API boundary per `api-contracts` (send `amountMinor:
Math.round(values.amount * 100)`), never send floats as money.

```tsx
"use client";
const form = useForm<DonationFormValues>({
  resolver: zodResolver(donationFormSchema),
  defaultValues: { donorName: "", amount: 0, currency: "GHS" },
});

const [createDonation, { isLoading }] = useCreateDonationMutation();

const onSubmit = form.handleSubmit(async (values) => {
  try {
    await createDonation(values).unwrap();
    toast.success("Donation recorded");
    form.reset();
  } catch (err) {
    toast.error(extractApiErrorMessage(err));
  }
});
```

Rules:
- `zodResolver` always; never hand-roll validation in the component.
- The Zod schema is the form's source of truth - derive the TS type with
  `z.infer`, don't declare a parallel interface.
- Disable submit while `isLoading`; reset/close on success; toast on error.

## Typed env for the browser

```ts
// lib/env.ts
const required = (name: string, v: string | undefined): string => {
  if (!v) throw new Error(`Missing required public env: ${name}`);
  return v;
};
export const PUBLIC_ENV = {
  SERVER_URI: required("NEXT_PUBLIC_SERVER_URI", process.env.NEXT_PUBLIC_SERVER_URI),
} as const;
```

*Why:* a missing `NEXT_PUBLIC_*` fails loudly at the first module load (build,
prerender, or first import) with a clear message, not as a silent `undefined`
baseUrl. Note `NEXT_PUBLIC_*` values are INLINED at build time - set them in
the build environment, and never put secrets in them.

## Hygiene
- No `console.*` in shipped code. If you need diagnostics, gate behind a dev-only
  logger that no-ops in production.
- No `any` - type props and responses; response types come from `types/`.
