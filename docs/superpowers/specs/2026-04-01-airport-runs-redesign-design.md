# Airport Runs Report — Redesign Spec

**Date:** 2026-04-01
**Status:** Approved
**Author:** Claude + Peter

---

## Problem

The v1 Airport Runs page has two separate grids — "Last Airport Journeys" (one row per driver, most recent trip) and "Airport Journeys" (all trips grouped by driver, expandable). The current v2 is a flat table of all trips with a count-based bar chart. The operator needs to quickly see which drivers have done airport runs, how much revenue each generated, and drill into individual trips.

## Design

### Layout (top to bottom)

1. Page header
2. Period pill tabs
3. Stat cards (4)
4. Revenue by driver chart
5. Expandable driver grid

### 1. Page Header

- Eyebrow: `BOOKING REPORTS`
- Title: `Airport Runs`
- Description: `Airport pickup and drop-off bookings by driver.`

### 2. Period Selector

Four pill/tab buttons in a horizontal row:

| Label | API `months` param |
|-------|--------------------|
| Last 1 Month | 1 |
| Last 3 Months | 3 |
| Last 6 Months | 6 |
| Last 12 Months | 12 |

- Default: **Last 3 Months**
- Active tab: primary colour fill
- Inactive tabs: ghost/outline variant
- Clicking re-fetches via `useAirportRuns(months)`

### 3. Stat Cards

Four `StatCard` components in a responsive grid (`grid-cols-1 sm:grid-cols-2 lg:grid-cols-4`):

| Label | Value | Icon | Source |
|-------|-------|------|--------|
| Total Runs | count of `lastAirports` | `Plane` | `data.length` |
| Total Revenue | sum of all prices | `PoundSterling` | `sum(price)`, formatted with `fmtMoney` |
| Avg Per Run | total / count | `TrendingUp` | `totalRevenue / totalRuns`, `fmtMoney` |
| Active Drivers | unique driver count | `Users` | `Set(userId).size` |

### 4. Revenue by Driver Chart

`SectionCard` containing a horizontal `BarChart` (Recharts):

- **Data:** group `lastAirports` by `userId`, sum `price` per driver, sort descending
- **Y-axis:** driver `fullname` (with colour dot if possible via custom tick)
- **X-axis:** £ values, formatted with `fmtMoneyCompact`
- **Bar fill:** each driver's `color` field (from API). Fallback: `CHART.primary`
- **Tooltip:** custom — shows colour dot, driver name, run count, total revenue (using `fmtMoney`)
- **Height:** scales with number of drivers, min 200px, max 500px

### 5. Expandable Driver Grid

#### Data Transformation

Group `lastAirports[]` by `userId` to produce parent rows:

```typescript
type DriverSummary = {
  userId: number;
  fullname: string;
  color: string;
  runs: number;
  totalRevenue: number;
  avgPrice: number;
  lastRunDate: string; // ISO — max date from trips
  trips: AirportRunEntry[]; // individual trips, sorted newest first
};
```

Sort parent rows by `totalRevenue` descending (highest earners first).

#### Parent Row Columns

| Column | Width | Content |
|--------|-------|---------|
| Expand | 40px | Chevron icon, rotates 90° when expanded |
| Driver | auto | Colour dot + `(#id) fullname` |
| Runs | 80px | Trip count |
| Total Revenue | 120px | `fmtMoney(totalRevenue)` |
| Avg Price | 100px | `fmtMoney(avgPrice)` |
| Last Run | 130px | Formatted date of most recent trip |

- Parent rows have `SortableTableHead` on Driver, Runs, Total Revenue, Avg Price, Last Run
- Default sort: Total Revenue descending
- Click chevron OR anywhere on the row to toggle expand/collapse

#### Child Row Columns (expanded)

| Column | Content |
|--------|---------|
| Date/Time | Full timestamp: "30 Mar 2026, 15:45" |
| Journey | `pickup → destination` (arrow separator: `→`) |
| Price | `fmtMoney(price)` |

- Child rows indented with left border accent (`border-l-2 border-primary/30`)
- Sorted newest first within each driver
- All trips shown (no child-level pagination)
- Subtle background differentiation (`bg-muted/20`)

#### Pagination

- 10 parent rows per page (children don't count)
- Uses `TablePagination` component
- Pagination state resets when period changes

### API

**Endpoint:** `GET /api/v2/reporting/airport-runs?months={1|3|6|12}`
**Response:** `{ success, data: { lastAirports: LastTripModel[] }, errors }`

Each `LastTripModel`:
```
userId: number
fullname: string
identifier: string
color: string
pickup: string
destin: string
date: string (ISO)
price: number
```

No backend changes needed — the V2 endpoint already exists at `GET /api/v2/reporting/airport-runs?months={n}` in `ReportingController.cs` (line 162). It returns `{ success, data: { lastAirports: [...] }, errors }`. The `lastJourneys` field from V1 is not present — grouping is done client-side. The `identifier` field is ignored in favour of constructing `(#userId) fullname` directly.

### Components Used

- `PageHeader` — page title
- `StatCard` — 4 KPI cards (import icons from lucide-react)
- `SectionCard` — chart wrapper
- `SortableTableHead` — sortable parent columns
- `TablePagination` — parent-level paging
- `DataTableShell` — grid wrapper
- `DateRangePicker` — NOT used (period tabs instead)
- `fmtMoney`, `fmtMoneyCompact` — from `@/lib/format`
- `CHART`, `chartGrid`, `chartAxis`, `chartTooltip` — from `@/lib/chart-theme`
- Recharts: `BarChart`, `Bar`, `XAxis`, `YAxis`, `CartesianGrid`, `Tooltip`, `ResponsiveContainer`

### Files Modified

1. `src/app/(dashboard)/reports/airport-runs/page.tsx` — full rewrite
2. `src/lib/hooks/use-airport-runs.ts` — update types if needed (ensure `color` field present)

### Edge Cases

- **Empty data:** Show `EmptyState` component with message "No airport runs found for the selected period."
- **Error:** Show `AlertCircle` icon with "Failed to load airport runs" message
- **Loading:** Show `ShimmerBlock` skeletons — one `h-[80px]` for stat cards row, one `h-[300px]` for chart, one `h-[400px]` for grid
- **StatCard props:** `delta`, `trend`, and `description` are optional on the current `StatCard` component — only `label`, `value`, and `icon` are required
- **Price precision:** `fmtMoney` handles rounding to 2 decimal places via `toLocaleString`

### Prerequisites (all exist in working tree)

All referenced components and utilities already exist in the working tree (built during this admin-v2 alignment pass):
- `SortableTableHead`, `TablePagination`, `ShimmerBlock`, `StatCard` — in `@/components/admin/`
- `fmtMoney`, `fmtMoneyCompact` — in `@/lib/format.ts`
- `CHART`, `chartGrid`, `chartAxis`, `chartTooltip` — in `@/lib/chart-theme.ts`
- `useAirportRuns` hook — in `@/lib/hooks/use-airport-runs.ts`

### Constraints (from CLAUDE.md)

- No horizontal scrollbar
- Default sort: newest/highest first
- Monetary values: `fmtMoney` with thousands separators
- Driver names: colour dot + `(#id) Name`
- Pagination default: 10 rows
- Chart colours: from `@/lib/chart-theme`
- Loading: `ShimmerBlock` skeleton
