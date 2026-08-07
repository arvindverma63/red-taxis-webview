# Admin v2 Frontend — Progress & Handover

Last updated: 2026-04-14

## Current State: COMPLETE — WhatsApp chat widget added (2026-04-14)

Route counts are now split by source of truth to avoid drift:
- **59 dashboard routes with `page.tsx` files** (excluding pattern demos + style guide)
- **55 sidebar-exposed routes** from `APP_NAV_SECTIONS` (+1 WhatsApp Transcripts)
- **4 non-nav routes**: `/profile`, `/reports/completed`, `/reports/on-shift`, `/web-bookings/rejected`
All billing pages (invoicing, statements, credit notes) are complete.
Pusher real-time notifications with audio alerts are live.
WhatsApp chat widget live globally on every page.
COMPLETED_ROUTES dev labels removed — all menus white (production-ready).

All pages complete. `/dispatch` embeds the headless-dispatch app via iframe with postMessage auth.

**Latest session additions (2026-04-14 — WhatsApp chat widget):**
- Floating green WhatsApp bubble in bottom-right on every page, with unread count badge
- Split-view drawer (50vw desktop / 100vw mobile) — conversation list + live chat thread
- Take Over / Transfer / Return to AI / Close controls with Pusher sync
- Audio ping + Sonner toast for incoming customer messages
- Read state persisted in localStorage (per-operator unread tracking)
- Transcript review page at `/whatsapp/transcripts` — date + status filter, expandable rows, `.txt` export
- Shared Pusher client singleton (notification bell + WhatsApp widget share one WebSocket)
- WhatsApp Transcripts added to sidebar navigation
- 11 new components under `src/components/admin/whatsapp-*.tsx`
- 8 new React Query hooks under `src/lib/hooks/use-whatsapp-*.ts`
- Backend: 4 new MediatR handlers + 4 new controller routes + schema migration

**Previous session additions:**
- Pusher notification bell: real-time popover with type-coloured dots, unread badge, audio ping alert
- Per-notification dismiss (X), clear all, settings link
- Notification Preferences page: per-type mute toggles (Cash, Web, Cancellation, Timeout)
- User Profile page: identity card + preferences card, linked from header dropdown
- Booking & Dispatch: `/dispatch` embeds headless-dispatch via iframe + postMessage auth (Clerk/dev token)
- EF migration synced: MutePrefs columns + QrCodes table now tracked in snapshot
- Header search bar narrowed (fixed 256px) so page titles don't truncate

**Previous session additions:**
- Utilities section enabled with expandable nav (was greyed out)
- HVS Account Changes page LIVE — date range + action toggle + search + confirm dialog
- QR Code Marketing: nav section, QR CRUD, branded download, redirect tracking at /qr/{shortCode}
- Account Booker registration: Clerk org-level invitations, revoke access, active/pending status
- Statement Processing + History: two-grid billing workflow, PDF/email, mark paid
- Invoice Processor + History + Groups: inline editing, expandable rows, PDF/CSV download
- Credit Invoice + Credit Journeys + Credit Notes: full credit workflow
- 18 report pages with Recharts charts, comparison modes, pivot tables
- See docs/TODO-account-booker-migration.md for deferred account-booker app migration.

### New reusable components built:
- `DriverSelect` — typeahead by name/ID, colour dots, keyboard nav
- `AccountSelect` — typeahead by account number or business name, keyboard nav
- `PostcodeHeatmap` — Google Maps heat map for pickup density
- `QrCodePreview` — branded QR code generator with download
- `ManageBookerDialog` — Clerk booker registration, status view, revoke access
- `AccountFormDialog` — Account create/edit form with tariff assignment

### Completed pages (wired to real API)

| Page | Route | Status | Notes |
|------|-------|--------|-------|
| Dashboard | `/` | LIVE | Tables first (v1 layout), 11 stat cards, 30s auto-refresh |
| Local POIs | `/pois` | LIVE | 450 POIs, sortable, Add/Edit/Delete CRUD, type labels |
| Audit View | `/reports/audit` | LIVE | Search by booking ID, DiffBadge for old/new values |
| Company Settings | `/settings` | LIVE | Editable form, all v1 fields, save to API |
| Message Settings | `/messaging` | LIVE | 9 notification channels, radio pills, save |
| Web Bookings — All | `/web-bookings` | LIVE | 184 pending bookings, sortable, paginated |
| Web Bookings — Amendments | `/web-bookings/amendments` | LIVE | Amend/Cancel/Delete with confirmation dialogs |
| Web Bookings — Processed | `/web-bookings/accepted` | LIVE | Merged accepted+rejected, status filter pills |
| Availability Report | `/reports/availability` | LIVE | DriverSelect, 6 tabs, dual-axis chart, driver ranking |
| Driver Expenses | `/reports/expenses` | LIVE | Add Expense dialog, category chart, driver ranking |
| Driver Earnings | `/reports/earnings` | LIVE | Pie chart, driver ranking, earnings table with totals |
| Turndown History | `/reports/turndowns` | LIVE | Daily totals with amber highlights, £ value per turndown, Period Total footer |
| Airport Runs | `/reports/airport-runs` | LIVE | Redesigned: pill tabs, stat cards, revenue chart, expandable driver grid |
| Duplicate Bookings | `/reports/duplicate-bookings` | LIVE | Amber duplicate counts, single DatePicker |
| Count By Scope | `/reports/count-by-scope` | LIVE | Period selector (H/D/W/M/Y), Compare toggle, pivot table, grouped bar chart |
| Top Customer | `/reports/top-customer` | LIVE | Horizontal bar chart (primary red), customer ranking, depth=15 |
| Pickups By Postcode | `/reports/pickups-by-postcode` | LIVE | Top 20 postcodes bar chart (primary red) + Google Maps heat map |
| By Vehicle Type | `/reports/by-vehicle-type` | LIVE | Donut chart (primary red first), vehicle type breakdown |
| Average Duration | `/reports/average-duration` | LIVE | Line chart, Scope filter (All/Cash/Card/Account/Rank), Period selector (H/D/W/M/Q/Y) |
| Growth By Period | `/reports/growth-by-period` | LIVE | Month name dropdowns, pivot table with scope columns, primary red bars |
| Revenue By Month | `/reports/revenue-by-month` | LIVE | Primary red bars, monthly net total, £ axis |
| Payouts By Month | `/reports/payouts-by-month` | LIVE | Primary red bars, monthly payment due |
| Profitability On Invoice | `/reports/profitability-on-invoice` | LIVE | Monthly profit chart, invoice PDF links, account names (#accNo Name), footer totals |
| Total Profitability | `/reports/total-profitability` | LIVE | 4 KPI cards, Sales(red)/Payouts(green)/Profit(blue) bar chart |
| Profitability By Date Range | `/reports/profitability-by-date-range` | LIVE | 13 fields in 4 sections, scope-coloured icons (purple/green/blue) |
| ~~QR Code Adverts~~ | ~~`/reports/qr-scans`~~ | REMOVED | Replaced by Marketing > QR Codes |
| QR Codes (Marketing) | `/marketing/qr-codes` | LIVE | Create/manage QR codes, branded download, scan tracking, redirect at /qr/{code} |
| Driver Availability | `/availability` | LIVE | All drivers overview, single driver CRUD, quick actions (SR AM/PM/Both/Unavailable), delete with local state removal |
| Availability Logs | `/availability-logs` | LIVE | Audit trail with Created/Deleted diff badges, driver colour dots, full name in Changed By |
| Card Bookings | `/card-bookings` | LIVE | 47 card payments, status badges (Paid/Unpaid/Waiting), driver colour dots |
| Cancel Range | `/cancel-range` | LIVE | AccountSelect dropdown, DateRangePicker (future only), Preview before cancel, ConfirmDialog, cancel fix for null response |
| Accounts | `/accounts` | LIVE | Full CRUD, delete safety checks (uninvoiced + future bookings), tariff assignment |
| Account Tariffs | `/accounts` (tab) | LIVE | Tariff rate CRUD within accounts page |
| Account Bookers | `/accounts` (dialog) | LIVE | Clerk org-level invitations, active/pending status, revoke access, magenta icon |
| Drivers | `/drivers` | LIVE | Full CRUD, active/deactivated tabs, soft-delete/restore, vehicle type + role badges, colour dots, lockout toggle |
| Booking & Dispatch | `/bookings` | LIVE | 16-field search (4 rows), 2000 limit, pagination, cancelled row strikethrough |
| GPS Tracking | `/tracking` | LIVE | Google Maps, driver-coloured SVG taxi icons, driver dropdown, return view toggle, 15s auto-refresh |
| VAT Outputs | `/billing/vat-outputs` | LIVE | DateRangePicker, generate report, 3 stat cards, scope breakdown, CSV download |
| Tariffs | `/tariffs` | LIVE | Tariff configuration table with CRUD |
| Account Tariffs | `/account-tariffs` | LIVE | Account-specific tariff rate CRUD |
| HVS Account Changes | `/utilities/hvs-account-changes` | LIVE | DateRangePicker + Action toggle, preview/execute with ConfirmDialog, results table |
| Statement Processing | `/billing/statement-processing` | LIVE | Two-grid workflow (awaiting pricing + ready), inline editing, process driver sheets (PDFs + emails) |
| Statement History | `/billing/statement-history` | LIVE | Date range + driver filter, earnings breakdown, resend email, mark paid, PDF download |
| Invoice Processor | `/billing/invoice-processor` | LIVE | Two-grid account billing, inline editing, COA + driver price warning, email toggle |
| Invoice Processor (Grp) | `/billing/invoice-processor-grp` | LIVE | 3-level accordion (passenger → route → jobs), Singles + Shared tabs, PriceBulk, JOB MATCH |
| Invoice History | `/billing/invoice-history` | LIVE | Account + date range filter, expandable rows, PDF/CSV download, resend, mark paid, 4 stat cards |
| Credit Invoice | `/billing/credit-invoice` | LIVE | Void entire invoice + generate credit note |
| Credit Journeys | `/billing/credit-journeys` | LIVE | Partially credit specific bookings on an invoice |
| Credit Notes | `/billing/credit-notes` | LIVE | Grid with account filter, stat cards, PDF download per credit note |
| Notification Preferences | `/notifications` | LIVE | Per-type mute toggles (Cash, Web, Cancellation, Timeout), Bell/BellOff icons |
| User Profile | `/profile` | LIVE | Identity card (name, email, phone, role) + preferences card (driver colour, comms, last login) |
| Booking & Dispatch | `/dispatch` | LIVE | Embeds headless-dispatch via iframe + postMessage auth |

### Remaining:

No pages remaining — all planned production pages are LIVE.
(See route-count note at the top of this document.)

### Hidden placeholder pages (not in nav, "Coming Soon"):

These routes exist but are not linked from the sidebar navigation. They are
early scaffolds from the initial build that were never wired to API data.

| Page | Route | Notes |
|------|-------|-------|
| Completed Jobs | `/reports/completed` | "Coming Soon" — data available via `/bookings` search with status filter |
| On Shift | `/reports/on-shift` | "Coming Soon" — data partially available via `/drivers` on-shift endpoint |

**Total sidebar-exposed routes: 54. Total dashboard routes (excluding pattern/style-guide demos): 58.**

### Infrastructure fixes applied:
- **CORS**: Added `localhost:3000` to `appsettings.Development.json` allowed origins
- **Dev token**: `useApiToken` hook falls back to `/dev/token?user=Peter` when Clerk JWT unavailable (`NEXT_PUBLIC_USE_DEV_TOKEN=true`)
- **Dark theme**: Removed red hue — neutralised all dark mode HSL backgrounds to pure grey (hue 0, saturation 0%)
- **Header**: User name + email from Clerk, working sign-out button
- **DataTableShell**: Added `overflow-x-auto` to prevent column clipping
- **Chart theme**: Centralised colours + styling at `@/lib/chart-theme.ts` — all 18 report charts use it
- **Monetary formatting**: `fmtMoney()` + `fmtMoneyCompact()` at `@/lib/format.ts` — thousands separators everywhere
- **DateRangePicker**: All from/to date selections use single DateRangePicker (not two DatePickers)
- **DriverSelect**: Reusable typeahead component with colour dots, keyboard nav, ID prefix

### Standards established:
- All tables must have **sortable column headers** (SortableTableHead component)
- After update/refetch, rows must **preserve their position** (stable sort)
- **Pagination**: 10 rows per page default, uses TablePagination component
- **Monetary values**: Always use `fmtMoney()` — `£419,840.69` not `£419840.69`
- **Driver display**: Colour dot + `(#id) Name` format in all tables and dropdowns
- **Default sort**: Newest at top unless specified otherwise
- **DateRangePicker** for from/to dates, single **DatePicker** for single dates only
- **Period pill tabs** for report period selection (Last 1/3/6/12 Months) — not DateRangePicker
- **Charts**: Use `chart-theme.ts` colours — Account=magenta, Cash=green, Rank=blue, Card=orange

### New backend endpoints created:
- `GET /api/v2/reporting/airport-runs?months={n}` — airport runs report
- `POST /api/v2/reporting/driver-expenses` — driver expense report
- `POST /api/v2/reporting/driver-earnings` — driver earnings report
- `GET /api/v2/bookings/{bookingId}/audit` — booking audit trail
- `DELETE /api/v2/web-bookings/change-requests/{id}` — delete amendment request
- `POST /api/v2/reporting/driver-expenses/add` — add driver expense
- `GET /api/v2/accounts/invoices/{invoiceNo}/pdf` — invoice PDF download
- `POST /api/v2/marketing/qr-codes` — create QR code
- `GET /api/v2/marketing/qr-codes` — list QR codes with scan counts
- `DELETE /api/v2/marketing/qr-codes/{id}` — delete QR code
- `GET /qr/{shortCode}` — public QR redirect + scan tracking (no auth)
- `GET /api/v2/bookings/card-payments` — card payment bookings list
- `GET /api/v2/accounts/{accNo}/delete-check` — uninvoiced + future booking safety check
- `GET /api/v2/accounts/{accNo}/booker-status` — booker email, name, last booked, Clerk active/pending
- `POST /api/v2/accounts/{accNo}/register-booker` — Clerk org invitation + save booker details
- `DELETE /api/v2/accounts/{accNo}/revoke-booker` — delete Clerk user + revoke pending invitations
- `GET /api/v2/accounts/tariffs` — list account tariff rates
- `PUT /api/v2/accounts/tariffs` — create or update account tariff rate
- `GET /api/v2/drivers/deleted` — soft-deleted drivers
- `POST /api/v2/drivers/{userId}/restore` — restore deleted driver
- `GET /api/v2/drivers/expiries` — all driver document expiries
- `PUT /api/v2/drivers/{userId}/expiry` — update single expiry date
- `GET /api/v2/drivers/gps` — active driver GPS with full driver data (name, colour, regNo)
- `POST /api/v2/accounts/vat-outputs` — VAT report (JSON, not CSV)
- `POST /api/v2/bookings/search` — extended search (16 criteria, 2000 limit)
- `GET /api/v2/utilities/hvs-account-changes` — HVS account migration (preview + execute)

### New utility files:
- `@/lib/format.ts` — `fmtMoney()`, `fmtMoneyCompact()` for monetary formatting
- `@/lib/chart-theme.ts` — `CHART`, `SCOPE_COLOURS`, `EXPENSE_COLOURS`, `chartGrid`, `chartAxis`, `chartTooltip`
- `@/lib/hooks/use-driver-list.ts` — cached global driver list (5min TTL)
- `@/lib/hooks/use-accounts.ts` — account CRUD + booker management hooks (register, revoke, status)
- `@/components/admin/driver-select.tsx` — reusable driver typeahead with colour dots + keyboard nav
- `ClerkApiService.cs` — Clerk REST API wrapper (invitations, user lookup, delete, revoke)

---

## How to Resume

### 1. Start the environments

```bash
# Backend API (Terminal 1)
cd O:\RedTaxi\src\backend\RedTaxi.API
set SENDGRID_API_KEY=SG.fake
set ASPNETCORE_ENVIRONMENT=Development
set DATABASE_URL=
dotnet run --urls "http://localhost:5092"

# Admin v2 (Terminal 2)
cd O:\RedTaxi\src\frontend\apps\admin-v2
npm run dev
# Opens on http://localhost:3000

# V1 Admin (Terminal 3 — for comparison)
cd O:\RedTaxi\src\frontend\apps\admin
npm run dev
# Opens on http://localhost:5173
```

### 2. Login credentials

- **v1 admin** (localhost:5173): `Peter` / `test1234` (Internal JWT)
- **v2 admin** (localhost:3000): `peter@test.redtaxi.co.uk` / `AceTaxi2026!Dorset` (Clerk — Ace Taxis Dorset org)
  - Note: Clerk email code 2FA is enabled on the instance — use dev token for local dev instead
- **API**: Dev token at `http://localhost:5092/dev/token?user=Peter`

### 3. Alignment task

Open v1 and v2 side by side. For each page:
- Compare fields, columns, layout, and data shape
- Update the v2 page to match v1's content
- Update mock data types to match v2 API response shapes
- Note any v1 fields that need new v2 API endpoints

### 4. Git state

- **Branch**: `feature/admin-v2-scaffold`
- **Base**: `dev` branch (has PRs #12 and #13 merged)
- **Changed files**: ~200+ new/modified files in `src/frontend/apps/admin-v2/` + backend
- **Backend changes**: 175+ v2 endpoints across 21 V2 controllers (all routing-only), Pusher notifications, QrCodes, EF migration sync
- **Latest commits**: Pusher notification bell (audio + dismiss), EF migration sync, dispatch page split, search bar width fix
- **EF Migrations**: 4 total (InitialPostgres, AddNotificationLog, AddClerkUserId, SyncMutePrefsAndQrCodes)

---

## Stack

| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16.2.1 + React 19 |
| Auth | Clerk (`@clerk/nextjs`) — 42 test users, virtual emails |
| Data fetching | TanStack Query v5 (wired, not connected — mock data phase) |
| Forms | React Hook Form + Zod (installed, not yet used) |
| Charts | Recharts 3.8 |
| Styling | Tailwind v4 + shadcn/ui + semantic tokens |
| Toasts | Sonner |
| Icons | Lucide React |

---

## Pages Built (50 routes — all wired to real API data)

The completed pages table above (in section "Completed pages") is the authoritative
list of all 50 routes. Legacy mock data files still exist but are no longer used
by any active page — all pages fetch from the v2 API.

---

## Pages NOT Built

All billing pages are now COMPLETE. Only one placeholder remains:

| Page | Route | Status |
|------|-------|--------|
| Booking & Dispatch | `/dispatch` | Placeholder — page content to be designed |

---

## Key Files

### Layout & Shell
- `src/app/layout.tsx` — Root layout (Clerk + Query + Theme providers)
- `src/app/(dashboard)/layout.tsx` — Dashboard shell (AppShell + PageContainer)
- `middleware.ts` — Clerk route protection
- `src/components/admin/app-sidebar.tsx` — Sidebar navigation
- `src/components/admin/app-header.tsx` — Top header with breadcrumbs

### Navigation
- `src/lib/navigation.ts` — All nav sections, items, routes, PAGE_META

### API (connected)
- `src/lib/api.ts` — Typed fetch wrapper with Clerk token injection
- `src/lib/hooks/use-api-token.ts` — Clerk token hook with dev token fallback
- `src/lib/hooks/use-dashboard.ts` — Dashboard query hook (wired to `/api/v2/dashboard/stats`)
- `src/lib/hooks/use-pois.ts` — POI CRUD hooks (query + create/update/delete mutations)
- `src/lib/hooks/use-current-user.ts` — Current user query hook
- `.env.development` — API URL + Clerk test keys + `NEXT_PUBLIC_USE_DEV_TOKEN=true`

### Mock Data
- `src/lib/mock-dashboard.ts` — Dashboard stats, earnings, booking stats
- `src/lib/mock-drivers.ts` — Driver list, stats
- `src/lib/mock-accounts.ts` — Account list, stats
- `src/lib/mock-bookings.ts` — Bookings, web bookings, turndowns, action logs, expiry
- `src/lib/mock-pois.ts` — POI list, stats
- `src/lib/mock-settings.ts` — Company settings
- `src/lib/mock-notifications.ts` — Notification list
- `src/lib/mock-reports.ts` — All report data (14 report types)

### UI Components (from admin-ui)
- 24 UI primitives in `src/components/ui/`
- 21 admin patterns in `src/components/admin/`
- 3 theme components in `src/components/theme/`

---

## Backend State

### v2 API Endpoints: 150 across 23 controllers (19 API + 4 Platform) — 5 genuinely missing

PRs merged to `dev`:
- PR #12: v2a auth consolidation (23 controller fixes + Clerk users + login fix)
- PR #13: initial v2 admin endpoints (foundation for 8 controllers)
- Subsequent commits: expanded to 150 endpoints across 23 controllers (19 in RedTaxi.API + 4 in RedTaxi.Platform) — billing, marketing, utilities, user profile, notifications, dispatch, SaaS platform, and more

**Controllers:** AccountsController (13), AvailabilityController (7), BillingController (3), BookingsController (16), DashboardController (1), DeliveryStatusController (2), DispatchController (7), DriversController (13), InvoiceProcessingController (16), MarketingController (3), MessagingController (2), NotificationsController (5), POIController (4), PricingController (5), ReportingController (18), SettingsController (4), StatementProcessingController (9), StripeWebhookController (1), TenantOnboardingController (3), TenantStatusController (1), UserProfileController (9), UtilitiesController (1), WebBookingsController (7)

**Missing endpoints (5):**
- `POST /drivers/{id}/resend-login` — blocked by v2a (Clerk invitations)
- `GET /bookings/by-status` — not needed (dashboard + search cover this)
- `POST /bookings/{id}/send-card-reminder` — no UI action for this yet
- `GET /web-bookings/{id}/duration` — calculated client-side
- `POST /support/ticket` — no support ticket UI

### Pre-existing issues:
- `GET /api/v2/bookings` returns 500 (null ref)
- `POST /api/v2/bookings/search` requires Details + Passenger fields
- `GET /api/v2/tenant-status` non-standard envelope
- `GET /api/v2/notifications` non-standard envelope

### Clerk Test Environment:
- Org: `org_3BfMRNcpn9933cL6snGXJ7k1PAN` (Ace Taxis Dorset)
- 42 users with virtual emails (`@test.redtaxi.co.uk`)
- All `ClerkUserId` values backfilled in AppUsers
- Script: `scripts/clerk-create-users.py`

---

## What NOT to change

- Do NOT modify `src/frontend/apps/admin/` (v1 admin) — live production
- Do NOT modify `src/frontend/apps/dispatch/` — live production
- Do NOT change v1 API routes or response shapes
- Do NOT remove mock data files yet — may still be referenced by patterns pages
- Do NOT rebuild the booking creation form — using existing dispatch
