# Design: Utilities > HVS Account Changes

**Date:** 2026-04-02
**Feature:** Admin v2 — Utilities section with HVS Account Changes utility page
**Status:** Approved

---

## Context

The v1 admin exposes a data-correction utility at `GET /api/v1/AdminUI/Move9014To10026` that moves bookings for Harbour Vale School (HVS) from account 9014 to account 10026. It filters on pickup postcode DT9 4DN, excluding trips to "house" postcodes. The operator uses this periodically to correct account assignments within a date range.

Admin v2 has "Utilities" in the sidebar but it is disabled (greyed out, no href). This feature adds the first utility page and enables the nav section.

---

## Backend

### New controller
**File:** `src/backend/RedTaxi.API/Controllers/V2/UtilitiesController.cs`

```
GET /api/v2/utilities/hvs-account-changes?from={DateTime}&to={DateTime}&action={bool}
```

- `[ApiController]`, `[Authorize]`, v2 route prefix
- Wraps the existing `Move9014To10026.Query` handler — zero handler changes
- Returns standard v2 envelope: `{ success, data, errors }`
- Response `data` is an array of:
  ```ts
  { id, pickupDateTime, pickupAddress, pickupPostCode, destinationAddress, destinationPostCode, passengerName }
  ```

**Note:** The handler contains hardcoded account numbers (9014, 10026) and postcode (DT9 4DN). This is pre-existing ACE-specific behaviour — not changed.

---

## Frontend

### 1. Navigation (`src/frontend/apps/admin-v2/src/lib/navigation.ts`)

Replace the disabled Utilities entry with an expandable parent containing one child:

```ts
{
  title: "Utilities",
  icon: Wrench,
  description: "System utilities",
  children: [
    {
      title: "HVS Account Changes",
      href: "/utilities/hvs-account-changes",
      icon: ArrowRightLeft,
      description: "Move HVS bookings between accounts",
    },
  ],
}
```

Add `ArrowRightLeft` to the Lucide imports at the top of the file.

Add `PAGE_META` entry:
```ts
"/utilities/hvs-account-changes": {
  title: "HVS Account Changes",
  subtitle: "Move Harbour Vale School bookings from account 9014 to account 10026.",
  eyebrow: "Utilities",
},
```

### 2. Hook (`src/frontend/apps/admin-v2/src/lib/hooks/use-hvs-account-changes.ts`)

TanStack Query mutation (search-on-demand, not auto-fetched):

```ts
useMutation({
  mutationFn: ({ from, to, action }: { from: string; to: string; action: boolean }) =>
    apiGet<HvsBooking[]>(
      `/api/v2/utilities/hvs-account-changes?from=${from}&to=${to}&action=${action}`,
      token
    ),
})
```

Type `HvsBooking`:
```ts
export type HvsBooking = {
  id: number;
  pickupDateTime: string;
  pickupAddress: string;
  pickupPostCode: string;
  destinationAddress: string;
  destinationPostCode: string;
  passengerName: string;
};
```

### 3. Page (`src/frontend/apps/admin-v2/src/app/(dashboard)/utilities/hvs-account-changes/page.tsx`)

#### Layout

```
HVS Account Changes                     [eyebrow: Utilities]
Move Harbour Vale School bookings from account 9014 to account 10026.

┌─────────────────────────────────────────────────────────┐
│  Date Range: [Mar 03 – Apr 02]   Action [○ toggle]   [Search] │
└─────────────────────────────────────────────────────────┘

Results table (shown after first Search)
┌────┬──────────────────┬───────────────┬───────────────────────┬──────────────────────┐
│ ID │ Pickup Date/Time │ Passenger     │ Pickup                │ Destination          │
├────┼──────────────────┼───────────────┼───────────────────────┼──────────────────────┤
│    │                  │               │ Address (Postcode)    │ Address (Postcode)   │
└────┴──────────────────┴───────────────┴───────────────────────┴──────────────────────┘

Pagination (10 rows default, options: 10/25/50/100)
```

Date range default: last 30 days.
Action toggle label: "Action" (off = preview, on = execute).
Search button disabled while loading.

#### Interaction flow

**Preview (action=OFF):**
1. User clicks Search → API called with `action=false`
2. Results table populated with matching bookings
3. Subheader updates to "Showing N HVS Change Job(s)"

**Execute (action=ON):**
1. User clicks Search → API called with `action=false` first to get count
2. If count = 0: toast "No matching bookings in this date range"
3. If count > 0: `ConfirmDialog` opens:
   - Title: "Move HVS Bookings"
   - Description: `"Move {N} booking(s) from account 9014 to account 10026? This cannot be undone."`
   - Confirm button: "Move Bookings"
4. On confirm: API called with `action=true` → toast "Moved {N} bookings to account 10026" → table shows moved bookings
5. On cancel: dialog closes, no changes

#### Components used

- `DateRangePicker` from `@/components/ui/date-range-picker`
- `ConfirmDialog` from `@/components/admin/confirm-dialog` (description prop is string, not JSX)
- `SortableTableHead` from `@/components/admin/sortable-table-head`
- `TablePagination` from `@/components/admin/table-pagination`
- `ShimmerLines` for loading state
- `sonner` toast for success/error

#### Table columns

| Column | Field | Width | Notes |
|--------|-------|-------|-------|
| ID | `id` | 75px | Sortable, ascending default |
| Pickup Date/Time | `pickupDateTime` | 150px | Sortable, format `dd/MM/yyyy HH:mm` |
| Passenger | `passengerName` | 140px | Sortable, truncate |
| Pickup | `pickupAddress` + `pickupPostCode` | auto | Two-line: address, postcode in muted text |
| Destination | `destinationAddress` + `destinationPostCode` | auto | Two-line: address, postcode in muted text |

Default sort: pickup date descending.

### 4. COMPLETED_ROUTES

Add `/utilities/hvs-account-changes` to the set in `sidebar-nav-item.tsx`.

---

## Files Changed

| File | Change |
|------|--------|
| `Controllers/V2/UtilitiesController.cs` | New file |
| `src/lib/navigation.ts` | Utilities: disabled → expandable parent; add child + PAGE_META |
| `src/lib/hooks/use-hvs-account-changes.ts` | New hook file |
| `app/(dashboard)/utilities/hvs-account-changes/page.tsx` | New page |
| `components/admin/sidebar-nav-item.tsx` | Add route to COMPLETED_ROUTES |

---

## Verification

1. Run backend — `GET /api/v2/utilities/hvs-account-changes?from=2026-01-01&to=2026-04-02&action=false` returns array with v2 envelope
2. Sidebar: Utilities entry is clickable and expands to show "HVS Account Changes" child
3. Page loads, date range defaults to last 30 days
4. Search with action=OFF → table populates with matching bookings
5. Search with action=ON → ConfirmDialog shows with correct booking count → confirm moves bookings → toast fires → table shows results
6. `/utilities/hvs-account-changes` shows green LIVE badge in sidebar
