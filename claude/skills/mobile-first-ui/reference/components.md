# Canonical mobile-safe components

Copy these implementations instead of rediscovering the patterns. They encode
the hard-won rules from SKILL.md (safe truncation, width caps, dual render,
adaptive type). Adjust names/tokens to the project, keep the mechanics.

## CellText - capped, tooltipped secondary table cell

Bare `truncate` in a td without a width cap does nothing (the column
stretches). This is the one way secondary long-content columns render:

```tsx
// components/shared/cell-text.tsx
import { cn } from "@/lib/utils";

export function CellText({
  value,
  className,
  max = "max-w-[16rem]",
}: { value: string; className?: string; max?: string }) {
  return (
    <span
      title={value} // full value always reachable
      className={cn("block min-w-0 truncate", max, className)}
    >
      {value}
    </span>
  );
}
```

Stretch-column cell (exactly one per table, th and td both `w-2/5`, td adds
`max-w-0`): inside it use `max-w-[90%]` (85% with a leading avatar).

## Dual-render table (cards below md, real table from md)

One data definition, two renders; never scroll-only tables on phones:

```tsx
// components/<feature>/data-table/rows.tsx
const menuItemsFor = (row: Donation) => [
  { label: "View", href: `/donations/${row.id}` },
  { label: "Edit", onSelect: () => openEdit(row.id) },
];

export function DonationRows({ rows }: { rows: Donation[] }) {
  return (
    <>
      {/* phone: dense two-line rows showing ALL row data */}
      <ul className="md:hidden divide-y">
        {rows.map((r) => (
          <li key={r.id} className="flex items-center gap-2 py-2.5">
            <div className="min-w-0 flex-1">
              <div className="flex items-baseline gap-2">
                <span className="min-w-0 line-clamp-1 whitespace-normal [overflow-wrap:anywhere]">
                  {r.donorName}
                </span>
                <Money amountMinor={r.amountMinor} currency={r.currency} className="ml-auto flex-none" />
              </div>
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <span className="min-w-0 truncate">{r.campaignTitle}</span>
                <StatusBadge status={r.status} />
              </div>
            </div>
            <RowMenu items={menuItemsFor(r)} />
          </li>
        ))}
      </ul>
      {/* md+: the real table */}
      <table className="hidden md:table w-full">
        <thead>
          <tr>
            <th className="w-2/5 text-left">Donor</th>
            <th className="text-left">Campaign</th>
            <th className="text-right">Amount</th>
            <th className="text-left">Status</th>
            <th />
          </tr>
        </thead>
        <tbody>
          {rows.map((r) => (
            <tr key={r.id}>
              <td className="w-2/5 max-w-0">
                <span title={r.donorName} className="block min-w-0 max-w-[90%] truncate">{r.donorName}</span>
              </td>
              <td><CellText value={r.campaignTitle} /></td>
              <td className="text-right"><Money amountMinor={r.amountMinor} currency={r.currency} /></td>
              <td><StatusBadge status={r.status} /></td>
              <td><RowMenu items={menuItemsFor(r)} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </>
  );
}
```

Skeletons must match the density of BOTH renders (row-list skeleton below md,
table skeleton above).

## Money - compact at scale, exact on demand

```tsx
// components/shared/money.tsx
export function Money({
  amountMinor,
  currency,
  className,
}: { amountMinor: number; currency: string; className?: string }) {
  const amount = amountMinor / 100;
  const exact = new Intl.NumberFormat(undefined, { style: "currency", currency }).format(amount);
  const display =
    amount >= 1_000_000
      ? new Intl.NumberFormat(undefined, {
          style: "currency", currency, notation: "compact", maximumFractionDigits: 1,
        }).format(amount)
      : exact;
  // whitespace-nowrap + flex-none at call sites: money NEVER truncates
  return <span title={exact} className={cn("whitespace-nowrap tabular-nums", className)}>{display}</span>;
}
```

## Adaptive display type (long names/amounts render calmly)

```tsx
// components/shared/adaptive-type.ts
export const detailTitleCls = (text: string): string =>
  text.length > 80
    ? "text-lg font-semibold leading-snug"
    : text.length > 40
      ? "text-xl font-semibold leading-snug"
      : "text-2xl font-bold";

export const statValueCls = (text: string): string =>
  text.length > 12 ? "text-lg font-semibold" : text.length > 8 ? "text-xl font-bold" : "text-2xl font-bold";
```

Use with `line-clamp-2` (never `truncate`) on detail titles, plus
`[overflow-wrap:anywhere]`.

## DateInput - native date inputs render blank on mobile

```tsx
// components/shared/date-input.tsx
"use client";
import { useRef } from "react";

export function DateInput({ value, onChange, placeholder = "Select date", ...props }: DateInputProps) {
  const ref = useRef<HTMLInputElement>(null);
  return (
    <div className="relative w-full">
      <input
        ref={ref}
        type="date"
        value={value}
        onChange={onChange}
        // text-base = 16px: below that iOS zooms the page on focus
        className="peer w-full min-w-0 appearance-none rounded-md border px-3 py-2 text-base"
        {...props}
      />
      {!value && (
        // iOS/Android show nothing for an empty date input; overlay our own placeholder
        <span
          onClick={() => ref.current?.showPicker?.()}
          className="pointer-events-auto absolute inset-y-0 left-3 flex items-center text-muted-foreground peer-focus:hidden"
        >
          {placeholder}
        </span>
      )}
    </div>
  );
}
```

## Shared page header (one component, controls never straddle title+description)

```tsx
// components/shared/page-header.tsx
export function PageHeader({ title, description, actions }: PageHeaderProps) {
  return (
    <header className="mx-auto w-full max-w-7xl">
      {/* actions stack ABOVE the title when they can't share the row */}
      <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
        <h1 className={cn("min-w-0 line-clamp-2 [overflow-wrap:anywhere]", detailTitleCls(title))}>
          {title}
        </h1>
        {actions && <div className="flex flex-none flex-wrap gap-2">{actions}</div>}
      </div>
      {description && <p className="mt-1 text-muted-foreground">{description}</p>}
    </header>
  );
}
```

## Hardened dialog primitives (fix at the root, not per call site)

In the shared shadcn `dialog.tsx` (and alert-dialog), bake in:

```tsx
// DialogContent className additions:
"max-h-[calc(100dvh-2rem)] overflow-y-auto"
// DialogTitle / DialogDescription className additions:
"min-w-0 max-w-full [overflow-wrap:anywhere]"
```

Titles/descriptions interpolate user-authored names; hardening one dialog
inline is a smell because the next one overflows the same way.

## Safe single-line clamp (the truncate trap)

```
min-w-0 line-clamp-1 whitespace-normal [overflow-wrap:anywhere]
```

One visual line with ellipsis and ~1-char min-content. Plain `truncate` sets
`nowrap`, making min-content the FULL text width; it is only safe on flex-row
items whose parent width is already pinned.
