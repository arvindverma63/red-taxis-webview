# Admin v2 — Component Upgrade Tracker

> **STATUS: COMPLETED** — All components listed below have been built, published to the admin-ui
> registry (commit 04f96d1 + 30cee73), and installed in admin-v2. 49 standalone registry items
> now available. This document is kept for historical reference only.

Components and changes needed in the `admin-ui` library based on the v2 alignment pass.
Implement these in the shared library, then update admin-v2 to import from there.

Last updated: 2026-03-31

---

## 1. New shadcn Primitives to Add

These are standard shadcn components not yet in `admin-ui/components/ui/`:

| Component | Why needed | Install command |
|-----------|-----------|----------------|
| **Label** | Form field labels — currently using raw `<label>` tags with manual styling | `npx shadcn@latest add label` |
| **Collapsible** | Sidebar parent-child nav expand/collapse animation | `npx shadcn@latest add collapsible` |
| **Pagination** | Table pagination controls (see #2 below) | Custom — see spec |

---

## 2. Table Pagination Component (NEW — build this)

**Component:** `admin/table-pagination.tsx`

**Props:**
```tsx
type TablePaginationProps = {
  page: number;              // 0-based current page
  pageSize: number;          // rows per page
  totalItems: number;        // total row count
  onPageChange: (page: number) => void;
  onPageSizeChange: (size: number) => void;
  pageSizeOptions?: number[]; // default [10, 25, 50, 100]
};
```

**Layout:** Left side: "Rows per page" + Select dropdown. Right side: "1–25 of 184" text + First/Prev/Next/Last icon buttons.

**Usage:** Every data table page will wrap their filtered data:
```tsx
const paged = filtered.slice(page * pageSize, (page + 1) * pageSize);
// render paged rows
<TablePagination page={page} pageSize={pageSize} totalItems={filtered.length} ... />
```

**Where needed:** POIs (450 rows), Web Bookings (184 rows), Drivers, Accounts, Bookings, all report tables.

---

## 3. Sortable Table Header Component (NEW — extract from pages)

**Component:** `admin/sortable-table-head.tsx`

Currently every page duplicates this pattern:
```tsx
type SortKey = "name" | "postcode" | ...;
type SortDir = "asc" | "desc";

function getSortIcon(col, sortKey, sortDir) { ... }

<TableHead className="cursor-pointer select-none" onClick={() => toggleSort("name")}>
  Name {getSortIcon("name", sortKey, sortDir)}
</TableHead>
```

**Extract into:**
```tsx
<SortableTableHead
  label="Name"
  sortKey="name"
  currentSort={sortKey}
  currentDir={sortDir}
  onSort={toggleSort}
/>
```

Uses `ArrowUpDown` (unsorted), `ArrowUp` (asc), `ArrowDown` (desc) from Lucide.

---

## 4. Confirmation Dialog Component (NEW — extract from pages)

**Component:** `admin/confirm-dialog.tsx`

Currently POI delete and Amendment cancel/delete each build their own confirmation dialog. Extract a reusable one:

```tsx
<ConfirmDialog
  open={!!target}
  onOpenChange={(open) => !open && setTarget(null)}
  title="Delete POI"
  description={<>Are you sure you want to delete <strong>{name}</strong>?</>}
  confirmLabel="Delete"
  confirmVariant="destructive"  // "default" | "destructive"
  isPending={mutation.isPending}
  onConfirm={handleConfirm}
/>
```

---

## 5. Diff Value Badge Component (NEW)

**Component:** `admin/diff-badge.tsx`

For audit/change history pages — shows old vs new values like git diff:

```tsx
<DiffBadge type="removed" value="False" />   // red badge
<DiffBadge type="added" value="True" />       // green badge
```

**Styles:**
- Removed: `bg-red-500/10 text-red-400 ring-1 ring-inset ring-red-500/20 font-mono text-xs`
- Added: `bg-emerald-500/10 text-emerald-400 ring-1 ring-inset ring-emerald-500/20 font-mono text-xs`

---

## 6. Status Badge Component (UPDATE existing)

`admin/status-badge.tsx` already exists but needs these status mappings added:

| Status | Style |
|--------|-------|
| Pending | `bg-amber-500/15 text-amber-400 ring-amber-500/30` |
| Accepted | `bg-emerald-500/15 text-emerald-400 ring-emerald-500/30` |
| Rejected | `bg-red-500/15 text-red-400 ring-red-500/30` |
| Completed | `bg-emerald-500/15 text-emerald-400 ring-emerald-500/30` |
| Cancelled | `bg-red-500/15 text-red-400 ring-red-500/30` |
| En-route | `bg-blue-500/15 text-blue-400 ring-blue-500/30` |
| Allocated | `bg-blue-500/15 text-blue-400 ring-blue-500/30` |
| Unallocated | `bg-amber-500/15 text-amber-400 ring-amber-500/30` |

Rendered as: `<span className="inline-flex rounded-full px-2 py-0.5 text-[0.7rem] font-semibold uppercase ring-1 ring-inset ...">STATUS</span>`

---

## 7. Modifications to Existing Components

### StatCard — Make delta/trend/description optional
**File:** `admin/stat-card.tsx`
**Change:** Props `delta`, `trend`, `description` become optional. Only render the trend badge when `delta` + `trend` are provided. Only render the description when provided.
**Why:** Real API data returns counts only — no trend/delta.

### DataTableShell — Fix overflow clipping
**File:** `admin/data-table-shell.tsx`
**Change:** Change the content wrapper from no overflow to `overflow-x-auto`:
```diff
- <div className="px-3 pb-3 pt-1 sm:px-4">{children}</div>
+ <div className="overflow-x-auto px-3 pb-3 pt-1 sm:px-4">{children}</div>
```
**Why:** Tables with action columns were being clipped by `overflow-hidden` on the parent section.

### AppHeader — Wire Clerk user data + sign-out
**File:** `admin/app-header.tsx`
**Change:** Replace hardcoded "Dispatch Lead" / "demo@redtaxi.io" with `useUser()` from `@clerk/nextjs`. Add working sign-out via `useClerk().signOut()`. Show user initials in avatar.
**Why:** Header must show the actual logged-in user and sign-out must work.

### AppShell — Remove red gradient overlay
**File:** `admin/app-shell.tsx`
**Change:** Remove the `radial-gradient` overlay div with primary colour. Change outer div to `h-screen overflow-hidden` and SidebarInset to `min-w-0 flex-1 overflow-y-auto`.
**Why:** Red hue in dark mode. Content was overflowing viewport causing horizontal scrollbar.

### PageContainer — Remove max-width constraint
**File:** `admin/page-container.tsx`
**Change:** Remove `mx-auto max-w-7xl` — let content fill the available width.
**Why:** Wasted space on wider screens.

### Sidebar width — Increase from 16rem to 18rem
**File:** `ui/sidebar.tsx`
**Change:** `SIDEBAR_WIDTH = "18rem"` (was `"16rem"`).
**Why:** Nav items with badges were being truncated.

---

## 8. Theme Changes

### Dark mode — Neutralise warm hue
**File:** `globals.css`
**Change:** All `.dark` CSS variables changed from warm hue (HSL hue 18, saturation 4-8%) to neutral grey (hue 0, saturation 0%). Remove body `radial-gradient` overlays.

Key variables affected:
```css
--background: 0 0% 7%;        /* was 18 8% 8% */
--card: 0 0% 10%;             /* was 18 6% 11% */
--secondary: 0 0% 15%;        /* was 18 5% 16% */
--muted: 0 0% 15%;            /* was 18 5% 16% */
--border: 0 0% 19%;           /* was 18 4% 20% */
--surface-1: 0 0% 7%;         /* was 18 8% 8% */
--sidebar-background: 0 0% 7%; /* was 20 6% 8% */
/* ... all 20+ variables neutralised */
```

---

## Summary Checklist

### New to build:
- [ ] `npx shadcn add label` — Label primitive
- [ ] `npx shadcn add collapsible` — Collapsible primitive
- [ ] `admin/table-pagination.tsx` — Table pagination (spec above)
- [ ] `admin/sortable-table-head.tsx` — Sortable column header
- [ ] `admin/confirm-dialog.tsx` — Reusable confirmation dialog
- [ ] `admin/diff-badge.tsx` — Git-style diff value badges

### Existing to update:
- [ ] `admin/stat-card.tsx` — Optional delta/trend/description
- [ ] `admin/data-table-shell.tsx` — overflow-x-auto
- [ ] `admin/app-header.tsx` — Clerk user data + sign-out
- [ ] `admin/app-shell.tsx` — Remove gradient, fix layout overflow
- [ ] `admin/page-container.tsx` — Remove max-width
- [ ] `admin/status-badge.tsx` — Add status type mappings
- [ ] `ui/sidebar.tsx` — Width 16rem → 18rem
- [ ] `globals.css` — Neutralise dark mode hue
