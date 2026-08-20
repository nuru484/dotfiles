# Reference: Data Tables (the canonical admin-table architecture)

Read this before building ANY admin list/table view. This is the one blessed
shape - never improvise a table. Ownership is strict:

- **The server owns the data.** Tables consume the existing paginated list
  endpoints (`api-contracts`): the backend pages, sorts, filters, and
  searches. No client-side processing of a server dataset.
- **The URL owns the view state.** `?page=3&sort=createdAt:desc&search=ama`
  IS the table state - the single source of truth, parsed by ONE hook.
- **RTK Query owns fetching/caching** via the feature's generated hook.
- **TanStack Table owns only column defs + row model** (manual mode,
  headless), rendered through mobile-first-ui's dual-render pattern
  (row-list below `md`, real `<table>` from `md`).
- **Row selection is local component state** - never the URL.

## URL state: the single source of truth

Table state lives in `useSearchParams` and is written with
`router.replace(..., { scroll: false })`. Because the URL is the state:

- **Back/forward** restore the view you left when moving between routes.
- **Share/bookmark** reproduces the exact page/sort/filter for a teammate.
- **Refresh** loses nothing.
- The audit snapshot's "URL reflects state" rule holds by construction.

Param names are EXACTLY the `api-contracts` list contract: `page` (1-based),
`limit` (validated + capped), `sort` (`field:asc|desc`), `search`, plus typed
domain filters (`status`, ...). The SAME object flows
URL -> `useTableParams()` -> RTK Query -> backend; there is no renaming layer.

`replace`, not `push`: every page click or filter change as a history entry
makes the Back button useless. `scroll: false`: page 2 -> 3 is a state
change, not a navigation - the viewport must not jump to the top.

## useTableParams() - the one params hook (full spec)

```ts
// hooks/use-table-params.ts
"use client";

import { useCallback, useMemo } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { z } from "zod";

export const TABLE_DEFAULTS = { page: 1, limit: 20 } as const;
const MAX_LIMIT = 100; // mirror of the backend cap (api-contracts) - never exceed it

/**
 * Base params mirror the api-contracts list contract EXACTLY:
 * page (1-based), limit (capped), sort ("field:asc|desc"), search.
 * Each table extends this with its typed filters via `.extend({...})`.
 */
export const tableParamsSchema = z.object({
  page: z.coerce.number().int().min(1)
    .default(TABLE_DEFAULTS.page).catch(TABLE_DEFAULTS.page),
  limit: z.coerce.number().int().min(1).max(MAX_LIMIT)
    .default(TABLE_DEFAULTS.limit).catch(TABLE_DEFAULTS.limit),
  sort: z.string().regex(/^\w+:(asc|desc)$/).optional().catch(undefined),
  search: z.string().trim().min(1).max(255).optional().catch(undefined),
});

export type TableParams = z.infer<typeof tableParamsSchema>;

type ParamValue = string | number | boolean | undefined | null;

export function useTableParams<S extends z.ZodType<Record<string, unknown>>>(
  schema: S,
): {
  params: z.output<S>;
  setParams: (patch: Partial<Record<keyof z.output<S> & string, ParamValue>>) => void;
} {
  const searchParams = useSearchParams();
  const pathname = usePathname();
  const router = useRouter();

  // Parse + validate the raw searchParams. `.catch()` on every field means a
  // hand-edited `?page=banana&limit=9999` degrades to defaults/caps instead
  // of leaking NaN or an unbounded limit into the query hook.
  const params = useMemo(
    () => schema.parse(Object.fromEntries(searchParams.entries())),
    [schema, searchParams],
  );

  const setParams = useCallback(
    (patch: Partial<Record<string, ParamValue>>) => {
      const next = new URLSearchParams(searchParams.toString());
      for (const [key, value] of Object.entries(patch)) {
        if (value === undefined || value === null || value === "") next.delete(key);
        else next.set(key, String(value));
      }
      // Any change that isn't itself paging resets to page 1: searching or
      // filtering from page 7 must not request page 7 of the new result set.
      if (!("page" in patch)) next.delete("page");
      // Defaults stay out of the URL so shared links are clean.
      if (next.get("page") === String(TABLE_DEFAULTS.page)) next.delete("page");
      if (next.get("limit") === String(TABLE_DEFAULTS.limit)) next.delete("limit");
      const qs = next.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [searchParams, pathname, router],
  );

  return { params, setParams };
}
```

Notes:
- Per-table filter schemas are declared at MODULE scope (the hook memoizes on
  the schema reference; an inline `.extend()` re-parses every render).
- Next.js requires a `<Suspense>` boundary around `useSearchParams` consumers
  on statically rendered routes - wrap the table island in the page's
  `<Suspense>`, with the table skeleton as the natural fallback.

## Fetching: the parsed params feed RTK Query directly

```ts
const { params, setParams } = useTableParams(donationsTableParamsSchema);
const { data, isLoading, isFetching, isError, refetch } = useGetDonationsQuery(params);
```

No intermediate state, no effects copying URL values around, and NEVER a
debounce on the query hook itself. The feature api file's typed URL builder
appends the same names the schema parses:

```ts
// redux/donations-api.ts - URL builder emits the api-contracts param names
const buildDonationsUrl = (params: IDonationTableParams): string => {
  const q = new URLSearchParams();
  q.set("page", String(params.page));
  q.set("limit", String(params.limit));
  if (params.sort) q.set("sort", params.sort);
  if (params.search) q.set("search", params.search);
  if (params.status) q.set("status", params.status);
  return `/donations?${q.toString()}`;
};
```

### isLoading vs isFetching - the #1 table jank source

Spell this out on every table:

- **`isLoading`** = the FIRST load, nothing cached yet. Render the table
  SKELETON (matching both renders' density per mobile-first-ui).
- **`isFetching`** = a page/sort/filter transition. RTK Query's `data`
  already keeps the PREVIOUS args' result while the next one loads (its
  built-in previous-data behavior: `data` is "latest result regardless of
  arg", `currentData` is the one that goes undefined mid-flight - the
  keepPreviousData equivalent, no option needed). Keep the previous rows
  visible at reduced opacity with `aria-busy="true"`.

Rendering the skeleton on page transitions is the jank: a blank flash and a
full layout jump on every page click. Skeleton for `isLoading`, dimmed
previous rows for `isFetching`, always.

## Debounce ONLY the search input (300ms)

The search `<Input>` holds local state; the URL write trails it by 300ms.
The query hook is never debounced - it just consumes whatever the URL says
(`useDeferredValue` is for deferring expensive re-renders, not for this; the
debounced setter is the house pattern):

```tsx
const [searchInput, setSearchInput] = useState(params.search ?? "");
// Back/forward or a shared link changed the URL: resync the input.
useEffect(() => setSearchInput(params.search ?? ""), [params.search]);
// Debounced URL write - the only debounce in the whole table.
useEffect(() => {
  const t = setTimeout(() => {
    const trimmed = searchInput.trim();
    if ((params.search ?? "") !== trimmed) setParams({ search: trimmed || undefined });
  }, 300);
  return () => clearTimeout(t);
}, [searchInput, params.search, setParams]);
```

## Empty vs no-results (two different states, two different UIs)

- **No rows exist at all** (no search/filters active): this is an onboarding
  moment - `EmptyState` with a CTA to create the first record.
- **Zero matches for the active criteria**: the data exists, the filters hid
  it - a "No results" state with a **Clear filters** action. Never show the
  onboarding CTA here; it reads as data loss.

```tsx
const hasActiveCriteria = Boolean(params.search || params.status);
```

## Row selection & bulk actions

- Selection is `useState<RowSelectionState>({})`, keyed by row id via
  `getRowId` - LOCAL, never in the URL (transient work, not shareable view
  state; a shared link must not arrive with ghost checkmarks).
- Any view change (page/sort/search/filter) clears the selection - a stale
  selection spanning result sets is how bulk deletes hit the wrong rows.
- Bulk actions appear in a bar when `selectedCount > 0`; **destructive bulk
  actions always confirm** via `AlertDialog`, naming the count.
- The bulk mutation invalidates the LIST tag as usual (`data-layer.md`).

## TanStack manual mode - the non-negotiables

```ts
manualPagination: true,
manualSorting: true,
manualFiltering: true,
pageCount: data?.meta.totalPages ?? -1,
getCoreRowModel: getCoreRowModel(),
```

- `getCoreRowModel` ONLY. Adding `getSortedRowModel` / `getFilteredRowModel`
  / `getPaginationRowModel` re-processes the single server page on the
  client - the classic bug where "sorting" reorders 20 visible rows instead
  of the dataset.
- Column defs are `ColumnDef<IRow>[]` typed from the row type the
  `I*Response` carries (`types/`), never a hand-declared parallel shape.
- Enable sorting ONLY on columns in the backend's sort whitelist
  (`enableSorting: false` on the rest); the server validates `sort` anyway,
  but a dead sort control is a UI lie.
- State handlers translate TanStack updates into `setParams` calls - TanStack
  never owns page/sort/filter state, it only reflects the URL.

## The wired example (full)

One data definition, TanStack's row model feeding BOTH renders - that is the
seam into mobile-first-ui's dual-render pattern: below `md` the dense
row-list, from `md` the real table, selection and menus shared.

```tsx
// components/donations/data-table/donations-table.tsx
"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  flexRender,
  getCoreRowModel,
  useReactTable,
  type ColumnDef,
  type RowSelectionState,
  type SortingState,
} from "@tanstack/react-table";
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react";
import { toast } from "sonner";
import { z } from "zod";

import { tableParamsSchema, useTableParams } from "@/hooks/use-table-params";
import { useDeleteDonationsMutation, useGetDonationsQuery } from "@/redux/donations-api";
import { DONATION_STATUSES, type IDonation } from "@/types/donation.types";
import { extractApiErrorMessage } from "@/utils/api-error";
import { cn } from "@/lib/utils";
import { CellText } from "@/components/shared/cell-text";
import { Money } from "@/components/shared/money";
import { EmptyState } from "@/components/shared/empty-state";
import { ErrorState } from "@/components/shared/error-state";
// shadcn imports elided: Button, Checkbox, Input, Select*, AlertDialog*
// feature bits elided: StatusBadge, RowMenu, menuItemsFor, DonationsTableSkeleton

// ---- URL params: base contract + this table's typed filters ---------------

const donationsTableParamsSchema = tableParamsSchema.extend({
  status: z.enum(DONATION_STATUSES).optional().catch(undefined),
});
// This IS the endpoint's query-params type: one object flows
// URL -> hook -> RTK Query -> backend.
export type IDonationTableParams = z.infer<typeof donationsTableParamsSchema>;

// ---- sort param ("createdAt:desc") <-> TanStack SortingState ---------------

const toSortingState = (sort?: string): SortingState => {
  if (!sort) return [];
  const [id, dir] = sort.split(":");
  return [{ id, desc: dir === "desc" }];
};
const toSortParam = (sorting: SortingState): string | undefined =>
  sorting[0] ? `${sorting[0].id}:${sorting[0].desc ? "desc" : "asc"}` : undefined;

// ---- column defs: typed from the I*Response row type -----------------------
// Widths follow mobile-first-ui's column rules (exactly ONE w-2/5 stretch
// column; CellText caps on secondary text), carried on `meta` so th and td
// agree. (Projects may augment @tanstack/react-table's ColumnMeta instead.)

type ColumnClasses = { th?: string; td?: string };
const classesOf = (columnDef: { meta?: unknown }): ColumnClasses =>
  (columnDef.meta as ColumnClasses | undefined) ?? {};

const columns: ColumnDef<IDonation>[] = [
  {
    id: "select",
    enableSorting: false,
    meta: { th: "w-10", td: "w-10" } satisfies ColumnClasses,
    header: ({ table }) => (
      <Checkbox
        checked={
          table.getIsAllPageRowsSelected() ||
          (table.getIsSomePageRowsSelected() && "indeterminate")
        }
        onCheckedChange={(v) => table.toggleAllPageRowsSelected(v === true)}
        aria-label="Select all rows on this page"
      />
    ),
    cell: ({ row }) => (
      <Checkbox
        checked={row.getIsSelected()}
        onCheckedChange={(v) => row.toggleSelected(v === true)}
        aria-label={`Select donation from ${row.original.donorName}`}
      />
    ),
  },
  {
    accessorKey: "donorName",
    header: "Donor",
    meta: { th: "w-2/5 text-left", td: "w-2/5 max-w-0" } satisfies ColumnClasses,
    cell: ({ row }) => (
      <span title={row.original.donorName} className="block min-w-0 max-w-[90%] truncate">
        {row.original.donorName}
      </span>
    ),
  },
  {
    accessorKey: "campaignTitle",
    header: "Campaign",
    enableSorting: false, // not in the backend sort whitelist
    cell: ({ row }) => <CellText value={row.original.campaignTitle} />,
  },
  {
    accessorKey: "amountMinor",
    header: "Amount",
    meta: { th: "text-right", td: "text-right" } satisfies ColumnClasses,
    cell: ({ row }) => (
      <Money amountMinor={row.original.amountMinor} currency={row.original.currency} />
    ),
  },
  {
    accessorKey: "status",
    header: "Status",
    enableSorting: false,
    cell: ({ row }) => <StatusBadge status={row.original.status} />,
  },
  {
    id: "actions",
    enableSorting: false,
    cell: ({ row }) => <RowMenu items={menuItemsFor(row.original)} />,
  },
];

// ---- the table --------------------------------------------------------------

export function DonationsTable() {
  const { params, setParams } = useTableParams(donationsTableParamsSchema);
  const { data, isLoading, isFetching, isError, refetch } = useGetDonationsQuery(params);

  // Selection: LOCAL, keyed by row id, never the URL.
  const [rowSelection, setRowSelection] = useState<RowSelectionState>({});
  useEffect(() => setRowSelection({}), [params]); // any view change voids it

  // Search: local input, URL write debounced 300ms behind it.
  const [searchInput, setSearchInput] = useState(params.search ?? "");
  useEffect(() => setSearchInput(params.search ?? ""), [params.search]);
  useEffect(() => {
    const t = setTimeout(() => {
      const trimmed = searchInput.trim();
      if ((params.search ?? "") !== trimmed) setParams({ search: trimmed || undefined });
    }, 300);
    return () => clearTimeout(t);
  }, [searchInput, params.search, setParams]);

  const table = useReactTable({
    data: data?.data ?? [],
    columns,
    getRowId: (row) => row.id, // stable ids: selection survives refetches
    getCoreRowModel: getCoreRowModel(),
    // Manual mode: the server already paged/sorted/filtered this data.
    manualPagination: true,
    manualSorting: true,
    manualFiltering: true,
    pageCount: data?.meta.totalPages ?? -1,
    enableRowSelection: true,
    state: {
      pagination: { pageIndex: params.page - 1, pageSize: params.limit },
      sorting: toSortingState(params.sort),
      rowSelection,
    },
    // Handlers write to the URL - TanStack never owns this state.
    onPaginationChange: (updater) => {
      const prev = { pageIndex: params.page - 1, pageSize: params.limit };
      const next = typeof updater === "function" ? updater(prev) : updater;
      setParams({ page: next.pageIndex + 1, limit: next.pageSize });
    },
    onSortingChange: (updater) => {
      const next =
        typeof updater === "function" ? updater(toSortingState(params.sort)) : updater;
      setParams({ sort: toSortParam(next) });
    },
    onRowSelectionChange: setRowSelection,
  });

  // FIRST load only (no cached data yet) - transitions never hit this branch.
  if (isLoading || !data) return <DonationsTableSkeleton />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const hasActiveCriteria = Boolean(params.search || params.status);
  const selectedIds = Object.keys(rowSelection);
  const tableRows = table.getRowModel().rows;

  return (
    <div className="space-y-3">
      {/* Toolbar (arrangement rules live in mobile-first-ui):
          search always visible and full-width on phones */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
        <Input
          type="search"
          value={searchInput}
          onChange={(e) => setSearchInput(e.target.value)}
          placeholder="Search donors…"
          aria-label="Search donations"
          className="w-full sm:max-w-xs"
        />
        <Select
          value={params.status ?? "all"}
          onValueChange={(v) => setParams({ status: v === "all" ? undefined : v })}
        >
          {/* SelectTrigger w-full min-w-0 sm:w-40; items: All statuses + DONATION_STATUSES */}
        </Select>
        <p className="text-sm text-muted-foreground sm:ml-auto" aria-live="polite">
          {data.meta.total} donations
        </p>
      </div>

      {/* Bulk actions: only with a selection; destructive always confirms */}
      {selectedIds.length > 0 && (
        <BulkActionsBar selectedIds={selectedIds} onDone={() => setRowSelection({})} />
      )}

      {tableRows.length === 0 ? (
        hasActiveCriteria ? (
          // Zero matches for the active criteria - NOT the same as no data.
          <EmptyState
            title="No results"
            description="Nothing matches the current search and filters."
            action={
              <Button
                variant="outline"
                onClick={() => {
                  setSearchInput("");
                  setParams({ search: undefined, status: undefined });
                }}
              >
                Clear filters
              </Button>
            }
          />
        ) : (
          // No rows exist at all - onboarding moment with a CTA.
          <EmptyState
            title="No donations yet"
            description="Record the first donation to see it here."
            action={
              <Button asChild>
                <Link href="/donations/new">Record donation</Link>
              </Button>
            }
          />
        )
      ) : (
        // Page transitions: previous rows stay visible, dimmed + aria-busy.
        <div
          aria-busy={isFetching}
          className={cn("transition-opacity", isFetching && "pointer-events-none opacity-60")}
        >
          {/* THE DUAL-RENDER SEAM (mobile-first-ui): TanStack supplies the
              rows for BOTH renders, so selection/menus stay in sync. */}

          {/* Below md: dense two-line row list showing ALL row data */}
          <ul className="divide-y md:hidden">
            {tableRows.map((row) => {
              const r = row.original;
              return (
                <li key={row.id} className="flex items-center gap-2 py-2.5">
                  <Checkbox
                    checked={row.getIsSelected()}
                    onCheckedChange={(v) => row.toggleSelected(v === true)}
                    aria-label={`Select donation from ${r.donorName}`}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-baseline gap-2">
                      <span className="min-w-0 line-clamp-1 whitespace-normal [overflow-wrap:anywhere]">
                        {r.donorName}
                      </span>
                      <Money
                        amountMinor={r.amountMinor}
                        currency={r.currency}
                        className="ml-auto flex-none"
                      />
                    </div>
                    <div className="flex items-center gap-2 text-sm text-muted-foreground">
                      <span className="min-w-0 truncate">{r.campaignTitle}</span>
                      <StatusBadge status={r.status} />
                    </div>
                  </div>
                  <RowMenu items={menuItemsFor(r)} />
                </li>
              );
            })}
          </ul>

          {/* From md: the real table via flexRender over the same row model */}
          <table className="hidden w-full md:table">
            <thead>
              {table.getHeaderGroups().map((hg) => (
                <tr key={hg.id}>
                  {hg.headers.map((header) => {
                    const sorted = header.column.getIsSorted();
                    return (
                      <th
                        key={header.id}
                        className={cn("text-left", classesOf(header.column.columnDef).th)}
                        aria-sort={
                          sorted === "asc"
                            ? "ascending"
                            : sorted === "desc"
                              ? "descending"
                              : undefined
                        }
                      >
                        {header.isPlaceholder ? null : header.column.getCanSort() ? (
                          <button
                            type="button"
                            className="inline-flex items-center gap-1"
                            onClick={header.column.getToggleSortingHandler()}
                          >
                            {flexRender(header.column.columnDef.header, header.getContext())}
                            {sorted === "asc" ? (
                              <ArrowUp className="size-3.5" aria-hidden="true" />
                            ) : sorted === "desc" ? (
                              <ArrowDown className="size-3.5" aria-hidden="true" />
                            ) : (
                              <ArrowUpDown className="size-3.5 opacity-50" aria-hidden="true" />
                            )}
                          </button>
                        ) : (
                          flexRender(header.column.columnDef.header, header.getContext())
                        )}
                      </th>
                    );
                  })}
                </tr>
              ))}
            </thead>
            <tbody>
              {tableRows.map((row) => (
                <tr key={row.id} data-state={row.getIsSelected() ? "selected" : undefined}>
                  {row.getVisibleCells().map((cell) => (
                    <td key={cell.id} className={classesOf(cell.column.columnDef).td}>
                      {flexRender(cell.column.columnDef.cell, cell.getContext())}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {/* Pagination writes to the URL through the table handlers */}
      <div className="flex items-center justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          Page {params.page} of {Math.max(data.meta.totalPages, 1)}
        </p>
        <div className="flex gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.previousPage()}
            disabled={!table.getCanPreviousPage() || isFetching}
          >
            Previous
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={() => table.nextPage()}
            disabled={!table.getCanNextPage() || isFetching}
          >
            Next
          </Button>
        </div>
      </div>
    </div>
  );
}

// ---- bulk actions: destructive always confirms ------------------------------

function BulkActionsBar({ selectedIds, onDone }: { selectedIds: string[]; onDone: () => void }) {
  const [deleteDonations, { isLoading }] = useDeleteDonationsMutation();

  const onBulkDelete = async () => {
    try {
      await deleteDonations({ ids: selectedIds }).unwrap(); // invalidates the LIST tag
      toast.success(`${selectedIds.length} donations deleted`);
      onDone();
    } catch (err) {
      toast.error(extractApiErrorMessage(err));
    }
  };

  return (
    <div className="flex items-center justify-between rounded-md border bg-muted/50 px-3 py-2">
      <p className="text-sm" aria-live="polite">
        {selectedIds.length} selected
      </p>
      <div className="flex gap-2">
        <Button variant="ghost" size="sm" onClick={onDone}>
          Clear
        </Button>
        <AlertDialog>
          <AlertDialogTrigger asChild>
            <Button variant="destructive" size="sm" disabled={isLoading}>
              Delete
            </Button>
          </AlertDialogTrigger>
          <AlertDialogContent>
            <AlertDialogHeader>
              <AlertDialogTitle>Delete {selectedIds.length} donations?</AlertDialogTitle>
              <AlertDialogDescription>This action cannot be undone.</AlertDialogDescription>
            </AlertDialogHeader>
            <AlertDialogFooter>
              <AlertDialogCancel>Cancel</AlertDialogCancel>
              <AlertDialogAction onClick={onBulkDelete}>Delete</AlertDialogAction>
            </AlertDialogFooter>
          </AlertDialogContent>
        </AlertDialog>
      </div>
    </div>
  );
}
```

Checklist for any new table:

```
[ ] Params via useTableParams (page/limit/sort/search + typed filters), URL only
[ ] RTK Query hook consumes the parsed params object directly
[ ] manualPagination/manualSorting/manualFiltering; getCoreRowModel only
[ ] isLoading -> skeleton; isFetching -> dimmed previous rows + aria-busy
[ ] Search input debounced 300ms; nothing else debounced
[ ] Empty (CTA) vs no-results (clear filters) both handled
[ ] Selection local, cleared on view change; destructive bulk actions confirm
[ ] Column defs ColumnDef<IRow> from types/; sortable columns = backend whitelist
[ ] Dual render: row-list below md, table from md, one row model feeding both
```
