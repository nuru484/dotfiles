# Reference: Dashboards (recharts conventions)

Read this before building any dashboard/analytics view. recharts is the
blessed chart library (SKILL.md blessed table; rationale in
`pick-ui-library`). Tile sizing, grid density, and stat-tile structure
belong to `mobile-first-ui` (container queries, adaptive type, compact
money); THIS file owns how the charts themselves are built. Chart components
are client islands (`"use client"`) - recharts renders SVG in the browser;
keep the island to the tile, not the page.

## Theme via CSS variables - never hardcoded hex

Chart colors are `--chart-1`..`--chart-5` tokens defined in `globals.css`
for light AND dark, in the shadcn token style. Chart code references
`var(--chart-N)` only; a hex literal in chart code is a bug (it breaks one
of the two themes, and re-theming means hunting through JSX). Because the
colors are CSS variables, next-themes' class flip re-themes every chart with
zero JS.

```css
/* app/globals.css - shadcn token pattern: light on :root, dark under .dark */
:root {
  --chart-1: oklch(0.646 0.222 41.116);
  --chart-2: oklch(0.6 0.118 184.704);
  --chart-3: oklch(0.398 0.07 227.392);
  --chart-4: oklch(0.828 0.189 84.429);
  --chart-5: oklch(0.769 0.188 70.08);
}

.dark {
  --chart-1: oklch(0.488 0.243 264.376);
  --chart-2: oklch(0.696 0.17 162.48);
  --chart-3: oklch(0.769 0.188 70.08);
  --chart-4: oklch(0.627 0.265 303.9);
  --chart-5: oklch(0.645 0.246 16.439);
}

@theme inline {
  /* Tailwind v4 mapping so text-chart-1 / fill-chart-1 utilities exist */
  --color-chart-1: var(--chart-1);
  --color-chart-2: var(--chart-2);
  --color-chart-3: var(--chart-3);
  --color-chart-4: var(--chart-4);
  --color-chart-5: var(--chart-5);
}
```

Assignment rule: series take tokens in order (first series `--chart-1`,
second `--chart-2`, ...). A single-series chart is always `--chart-1`. Grid
lines use `var(--border)`, axis tick text `var(--muted-foreground)` - never
recharts' default `#ccc`/`#666`, which fail dark mode.

## Layout: ResponsiveContainer inside the container-query shell

- The dashboard grid is sized by container queries on `<main>`
  (`@container/main`, `@2xl/main:grid-cols-2`, ... - `mobile-first-ui` owns
  those rules). Charts never set their own widths; they fill their tile.
- `ResponsiveContainer` needs a parent with REAL height - against an unsized
  parent it renders 0px tall. State the min-height explicitly: the house
  default chart body is `h-64 min-h-64` (256px) inside the tile, then
  `<ResponsiveContainer width="100%" height="100%">`.

## Formatting: house Intl formatters only

Every axis tick and tooltip value goes through the shared formatters - never
inline `.toFixed()`, raw `toLocaleDateString()` variants, or hand-built
currency strings. These are the string counterparts of the `Money`
component (`mobile-first-ui` reference/components.md) and follow its rules:
money from integer minor units, compact from 1M.

```ts
// lib/formatters.ts - the house Intl formatters for charts, tiles, tables
export const formatMoneyMinor = (amountMinor: number, currency: string): string => {
  const amount = amountMinor / 100;
  // Compact from 1M per mobile-first-ui's Money rules; exact below that.
  return new Intl.NumberFormat(
    undefined,
    amount >= 1_000_000
      ? { style: "currency", currency, notation: "compact", maximumFractionDigits: 1 }
      : { style: "currency", currency },
  ).format(amount);
};

// Axis ticks are ALWAYS compact - a tick like "GHS 2,412.50" wrecks the gutter.
export const formatAxisMoney = (amountMinor: number, currency: string): string =>
  new Intl.NumberFormat(undefined, {
    style: "currency",
    currency,
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(amountMinor / 100);

export const formatCompactNumber = (n: number): string =>
  new Intl.NumberFormat(undefined, {
    notation: n >= 1_000_000 ? "compact" : "standard",
  }).format(n);

// Dates via Intl.DateTimeFormat, never string slicing of ISO dates.
export const formatChartDate = (iso: string): string =>
  new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric" }).format(new Date(iso));
```

## States: every tile handles loading / error / empty

- **Loading**: a skeleton matching the CHART'S SHAPE (tile header line +
  a block the same height as the chart body) so nothing shifts on arrival.
- **Error**: the shared `ErrorState` with retry.
- **Empty**: a "No data yet" state. **Never render an empty-axes chart** -
  axes around nothing read as a bug, not as an empty dataset.

## Accessibility (per reference/a11y-seo.md)

An SVG chart is invisible to assistive tech; every chart tile pairs the
visual with accessible data:

- The chart container gets `role="img"` + an `aria-label` that SUMMARIZES
  the data (total, span, trend) - not just "chart".
- The underlying numbers are reachable: an `sr-only` `<table>` in the tile
  (small datasets) or a link to the real data table / detail view that holds
  them.
- Tooltips use popover tokens (`bg-popover text-popover-foreground border`),
  legends use `var(--foreground)` - both must pass AA contrast in BOTH
  themes; recharts' grey defaults do not.
- Meaning never rides on color alone: multi-series charts differentiate by
  label/legend text, not only hue.

## Density

4-6 KPI stat tiles + 1-2 charts per view, maximum. More belongs on a
drill-down page. (Tile arrangement, 2-up thresholds, and adaptive stat type
stay with `mobile-first-ui`.)

## Wired example: stat tiles + AreaChart from one RTK Query endpoint

Types and endpoint (per `data-layer.md`; the dashboard endpoint provides the
`DashboardStats` tag and takes the `buildDateRangeUrl`-style params):

```ts
// types/dashboard.types.ts
import type { IApiResponse } from "./api";

export interface ITrendPoint {
  date: string; // ISO 8601, per api-contracts wire formats
  amountMinor: number;
}

export interface IDashboardStats {
  totalDonationsMinor: number;
  currency: string;
  donorCount: number;
  campaignCount: number;
  avgDonationMinor: number;
  trend: ITrendPoint[];
}

export type IDashboardStatsResponse = IApiResponse<IDashboardStats>;
```

```tsx
// components/dashboard/dashboard-overview.tsx
"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { useGetDashboardStatsQuery } from "@/redux/dashboard-api";
import type { ITrendPoint } from "@/types/dashboard.types";
import {
  formatAxisMoney,
  formatChartDate,
  formatCompactNumber,
  formatMoneyMinor,
} from "@/lib/formatters";
import { statValueCls } from "@/components/shared/adaptive-type";
import { EmptyState } from "@/components/shared/empty-state";
import { ErrorState } from "@/components/shared/error-state";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

export function DashboardOverview() {
  const { data, isLoading, isError, refetch } = useGetDashboardStatsQuery({ preset: "30d" });

  if (isLoading || !data) return <DashboardSkeleton />;
  if (isError) return <ErrorState onRetry={() => refetch()} />;

  const stats = data.data;

  return (
    // Container-queried grid: mobile-first-ui owns the tile sizing rules.
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3 @4xl/main:grid-cols-4">
        <StatTile
          label="Total donations"
          value={formatMoneyMinor(stats.totalDonationsMinor, stats.currency)}
        />
        <StatTile label="Donors" value={formatCompactNumber(stats.donorCount)} />
        <StatTile label="Campaigns" value={formatCompactNumber(stats.campaignCount)} />
        <StatTile
          label="Average gift"
          value={formatMoneyMinor(stats.avgDonationMinor, stats.currency)}
        />
      </div>
      <DonationsTrendCard trend={stats.trend} currency={stats.currency} />
    </div>
  );
}

function StatTile({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border p-4">
      <p className="text-sm text-muted-foreground">{label}</p>
      {/* length-adaptive type (mobile-first-ui) so big figures render calmly;
          the full figure is already compacted by the formatter, exact value
          belongs on the detail view */}
      <p title={value} className={cn("tabular-nums", statValueCls(value))}>
        {value}
      </p>
    </div>
  );
}

function DonationsTrendCard({ trend, currency }: { trend: ITrendPoint[]; currency: string }) {
  // Empty state INSTEAD of an empty-axes chart - never chart nothing.
  if (trend.length === 0) {
    return (
      <EmptyState
        title="No data yet"
        description="Donations will chart here once the first one is recorded."
      />
    );
  }

  const totalMinor = trend.reduce((sum, p) => sum + p.amountMinor, 0);
  const summary =
    `Donations over the last 30 days: ${formatMoneyMinor(totalMinor, currency)} total ` +
    `across ${trend.length} days.`;

  return (
    <section className="rounded-lg border p-4" aria-label="Donations trend">
      <h2 className="text-sm font-medium">Donations, last 30 days</h2>

      {/* Explicit height: ResponsiveContainer renders 0px in an unsized parent */}
      <div role="img" aria-label={summary} className="mt-3 h-64 min-h-64">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={trend} margin={{ top: 4, right: 4, bottom: 0, left: 0 }}>
            <CartesianGrid stroke="var(--border)" strokeDasharray="3 3" vertical={false} />
            <XAxis
              dataKey="date"
              tickFormatter={formatChartDate}
              tick={{ fill: "var(--muted-foreground)", fontSize: 12 }}
              axisLine={{ stroke: "var(--border)" }}
              tickLine={false}
              minTickGap={24}
            />
            <YAxis
              width={56}
              tickFormatter={(v: number) => formatAxisMoney(v, currency)}
              tick={{ fill: "var(--muted-foreground)", fontSize: 12 }}
              axisLine={false}
              tickLine={false}
            />
            <Tooltip content={<TrendTooltip currency={currency} />} />
            <Area
              type="monotone"
              dataKey="amountMinor"
              stroke="var(--chart-1)"
              strokeWidth={2}
              fill="var(--chart-1)"
              fillOpacity={0.15}
              activeDot={{ r: 3 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* The numbers behind the picture, reachable for assistive tech */}
      <table className="sr-only">
        <caption>Daily donation totals, last 30 days</caption>
        <thead>
          <tr>
            <th scope="col">Date</th>
            <th scope="col">Amount</th>
          </tr>
        </thead>
        <tbody>
          {trend.map((p) => (
            <tr key={p.date}>
              <td>{formatChartDate(p.date)}</td>
              <td>{formatMoneyMinor(p.amountMinor, currency)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </section>
  );
}

// Tooltip: popover tokens (AA in both themes), house formatters only.
function TrendTooltip({
  active,
  payload,
  label,
  currency,
}: {
  active?: boolean;
  payload?: { value: number }[];
  label?: string;
  currency: string;
}) {
  if (!active || !payload?.length || !label) return null;
  return (
    <div className="rounded-md border bg-popover px-3 py-2 text-sm text-popover-foreground shadow-md">
      <p className="text-muted-foreground">{formatChartDate(label)}</p>
      <p className="font-medium tabular-nums">{formatMoneyMinor(payload[0].value, currency)}</p>
    </div>
  );
}

// Skeleton matches the real shape: 4 tiles + a chart-height block.
function DashboardSkeleton() {
  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-3 @4xl/main:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-20 rounded-lg" />
        ))}
      </div>
      <Skeleton className="h-80 rounded-lg" /> {/* header + h-64 chart body */}
    </div>
  );
}
```

Checklist for any new dashboard tile:

```
[ ] Colors via var(--chart-N)/var(--border)/var(--muted-foreground) - zero hex
[ ] Chart body has explicit height (h-64 default); fills its tile, no own width
[ ] Axis + tooltip values through lib/formatters (money from minor units,
    compact >= 1M, Intl dates)
[ ] isLoading -> shape-matched skeleton; isError -> ErrorState;
    empty -> "No data yet" (never empty axes)
[ ] role="img" + aria-label summary; numbers reachable (sr-only table or link)
[ ] Tooltip/legend on popover/foreground tokens - AA in both themes
[ ] View totals: 4-6 KPI tiles + 1-2 charts, no more
```
