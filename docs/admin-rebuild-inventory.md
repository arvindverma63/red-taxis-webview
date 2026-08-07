# Admin Frontend — Rebuild Inventory

**Created:** 2026-03-29
**Purpose:** Page-by-page spec for rebuilding the admin frontend.
**Target stack:** Next.js (or Vite + React), Tailwind + shadcn/ui, TanStack Query + Table, Clerk auth, v2 API only.

---

## Current State

| Metric | Value |
|--------|-------|
| Total source files | 1,108 |
| Total lines of code | 88,164 |
| Active routes | ~45 |
| Template bloat (unused) | ~60% of codebase |
| Styling systems | 4 (MUI, Emotion, Tailwind, styled-components) |
| Auth | Custom JWT in localStorage |
| State | Redux Toolkit (12 slices, 1,667 lines) |
| API layer | 13 service files (3,049 lines), all v1 endpoints |
| Tests | Zero |

---

## Page Inventory

### Legend
- **R** = Read-only (fetch + display)
- **RW** = Read + Write (forms, CRUD, actions)
- **Complexity:** Simple (table + fetch), Medium (forms + validation + actions), Complex (multi-step workflows, calculations, maps)
- **Role gate:** 1 = Admin only, !2 = Not restricted users, * = All users

---

### Dashboard
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Dashboard Home | `/` | R | Simple | * | KPI cards + charts. ApexCharts. |

**API:** `/api/v2/dashboard/stats` (or equivalent)

---

### Bookings — Views
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Booking Dispatch | `/bookings/booking-dispatch` | RW | Medium | * | Status table with allocate action |
| Amendment Bookings | `/bookings/amend-booking` | RW | Medium | * | Review + accept/reject amendments |
| Accepted Bookings | `/bookings/accept-booking` | RW | Medium | * | List with actions |
| Rejected Bookings | `/bookings/reject-booking` | RW | Medium | * | List with actions |
| Turndown Bookings | `/bookings/turndown` | R | Simple | * | Read-only list |
| Airport Runs | `/bookings/airport-runs` | R | Simple | * | Read-only list |
| Card Bookings | `/bookings/card-bookings` | RW | Medium | 1 | Card payment bookings + send reminder |
| Global Search | `/bookings/global-search` | RW | Simple | * | Search across all bookings |

**Rebuild pattern:** All use the same table component with different filters/endpoints.

---

### Bookings — Admin Actions
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Audit View | `/bookings/audit-view` | R | Simple | 1 | Booking change history |
| Cancel by Range | `/bookings/cancelbyrange` | RW | Medium | 1 | Date picker + bulk cancel |
| Cancel by Range Report | `/bookings/cancelbyrangereport` | R | Simple | 1 | Results of cancellation |

---

### Bookings — New Booking
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| New Web Booking | `/bookings/web-booking` | RW | **Complex** | * | 969 lines. Multi-step form: address lookup (Google Places), vehicle selection, pricing calc, passenger details. |

**This is one of the 5 complex pages. Needs careful rebuild.**

---

### Driver Management
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Driver List | `/drivers/list-driver` | RW | Medium | !2 | CRUD table. Inline modals for add/edit/delete. Lockout toggle. |
| Driver Expiry | `/drivers/expires` | RW | Medium | !2 | Document expiry tracking + update |
| Driver Expenses | `/driver-expenses` | R | Simple | !2 | Read-only with export |
| Driver Earning Report | `/driver-earning-report` | R | Simple | !2 | Date range + table |
| Driver Tracking | `/booking/driver-tracking` | R | **Complex** | * | Real-time GPS on map. 10-sec polling. Leaflet/Google Maps. |

---

### Availability
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Availability | `/booking/availability` | RW | Medium | * | Set/delete driver availability slots |
| Availability Logs | `/booking/availability-logs` | R | Simple | * | Audit trail |
| Availability Report | `/booking/availability-report` | R | Simple | * | Analytics view |

---

### Accounts
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Account List | `/accounts/list-account` | RW | Medium | !2 | CRUD table. Add/edit/delete accounts. Web booker registration. |
| Account Tariffs | `/accountTariffs` | RW | Medium | !2 | Per-account pricing overrides |

---

### Local POI
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| POI List | `/localPOIs/list-local-Poi` | RW | Medium | * | CRUD + map display (Leaflet) |

---

### Billing & Payments — Driver
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Statement Processing | `/billing/driver/statement-processing` | RW | **Complex** | !2 | **1,869 lines.** Multi-step: select jobs → price by mileage → post → create statements. Heavy business logic. |
| Statement History | `/billing/driver/statement-history` | R | Simple | !2 | Read-only list |

---

### Billing & Payments — Account
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Invoice Processor | `/billing/account/invoice-processor` | RW | **Complex** | !2 | **2,144 lines — largest file.** Multi-step pricing, mileage calculations, bulk operations. |
| Invoice Processor Groups | `/billing/account/invoice-processor-grp` | RW | **Complex** | !2 | Group invoicing with priced/not-priced split. 813+ lines per sub-page. |
| Invoice History | `/billing/account/invoice-history` | R | Simple | !2 | Read-only + PDF download |
| Credit Invoices | `/billing/account/credit-invoice` | RW | Medium | !2 | Credit/void invoices |
| Credit Journeys | `/billing/account/credit-journeys` | RW | Medium | !2 | Journey-level credits |
| Credit Notes | `/billing/account/credit-notes` | R | Medium | !2 | View + download |
| VAT Outputs | `/billing/vat-outputs` | R | Simple | !2 | Read-only |

---

### Tariffs
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Tariff Config | `/tariffs` | RW | Medium | !2 | Pricing matrix configuration |

---

### Reports (ALL read-only, ALL simple)
| Page | Route | Role |
|------|-------|------|
| Duplicate Bookings | `/bookings/duplicate-bookings` | * |
| Count by Scope | `/bookings/count-by-scope` | * |
| Top Customer | `/bookings/top-customer` | !2 |
| Growth by Period | `/bookings/growth-by-period` | !2 |
| Pickups by Postcode | `/bookings/pickups-by-postcode` | * |
| By Vehicle Type | `/bookings/by-vehicle-type` | * |
| Average Duration | `/bookings/average-duration` | * |
| Payouts by Month | `/financial/payouts-by-month` | !2 |
| Revenue by Month | `/financial/revenue-by-month` | !2 |
| Profitability on Invoice | `/financial/profitability-on-invoice` | !2 |
| Total Profitability by Period | `/financial/total-profitability-by-period` | !2 |
| Profitability by Date Range | `/financial/profitability-by-date-range` | !2 |
| QR Code Scans | `/financial/qr-code-adverts` | !2 |

**Rebuild pattern:** One shared `<ReportPage>` component with date range selector + chart + table. Each report just passes endpoint + columns config.

---

### Settings
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| Company Settings | `/setting/company-settings` | RW | Simple | !2 | Form with save |
| Message Settings | `/setting/msg-settings` | RW | Simple | !2 | SMS/WhatsApp config |

---

### Utilities
| Page | Route | R/RW | Complexity | Role | Notes |
|------|-------|------|-----------|------|-------|
| HVS Account Changes | `/utilities/hvs-account-changes` | RW | Medium | !2 | Bulk account updates |

---

## Complexity Summary

| Complexity | Count | Pages |
|-----------|-------|-------|
| **Simple** | ~22 | Dashboard, all 13 reports, statement history, invoice history, VAT, audit, turndown, airport runs, cancel report, availability logs/report, driver expenses, driver earning, settings x2 |
| **Medium** | ~18 | Booking dispatch, amendments, accept, reject, card bookings, cancel by range, global search, driver list, driver expiry, availability, accounts, account tariffs, POI, credit invoices, credit journeys, credit notes, tariff config, HVS changes |
| **Complex** | ~5 | New booking form, invoice processor, invoice processor groups, statement processing, driver tracking (GPS map) |

---

## The 5 Complex Pages — Detail

These need the most attention during rebuild:

### 1. Invoice Processor (2,144 lines)
- Multi-step workflow: load unbilled journeys → calculate by mileage → apply pricing → generate invoice
- Heavy table with inline editing
- Bulk select + price operations
- PDF generation (jsPDF)
- **Rebuild estimate:** 800-1000 lines with modern patterns

### 2. Statement Processing (1,869 lines)
- Multi-step: select driver → load jobs → price → post statement
- Mileage-based pricing calculations
- Driver selection + date range filtering
- **Rebuild estimate:** 600-800 lines

### 3. New Booking Form (969 lines)
- Address autocomplete (Google Places)
- Vehicle type selection
- Real-time pricing calculation
- Passenger details + notes
- **Rebuild estimate:** 400-500 lines

### 4. Invoice Processor Groups (813+ lines per sub-page)
- Shared vs Singles grouping
- Priced vs Not-priced split (4 sub-pages)
- Same pricing logic as Invoice Processor
- **Rebuild estimate:** 500-600 lines total (shared component)

### 5. Driver Tracking (681 lines)
- Real-time GPS map (10-sec polling)
- Leaflet/Google Maps integration
- Driver markers with status colours
- **Rebuild estimate:** 300-400 lines with react-leaflet

---

## API Layer

All current endpoints are v1 (`/api/AdminUI/*`, `/api/UserProfile/*`, `/api/Accounts/*`).

The rebuild should use **v2 endpoints only** (`/api/v2/*`) which return the standard envelope:
```json
{ "success": true, "data": {...}, "errors": [] }
```

The v2 API layer for the rebuild is ~1 file: a configured TanStack Query client with Clerk auth token injection.

---

## Auth for Rebuild

Replace:
- Custom JWT in localStorage
- Redux authSlice
- RequireAuth route wrapper
- Login/signup pages

With:
- Clerk `<SignIn />`, `<SignUp />`, `<UserButton />`
- Clerk `useAuth()` hook for token
- Clerk `<OrganizationSwitcher />` for multi-tenant
- `clerkMiddleware()` route protection

---

## What to Delete (not rebuild)

These exist in the current codebase but are **template bloat** — not used by any route:

| Directory | Files | Lines | Why it exists |
|-----------|-------|-------|--------------|
| `/pages/account/` (settings template) | 182 | ~15,000 | Purchased admin template (Metronic-style) |
| `/pages/public-profile/` | 100 | ~6,400 | Template — social profile pages |
| `/pages/network/` | 39 | ~6,000 | Template — team/member pages |
| `/partials/modals/` (template modals) | ~50 | ~4,000 | Template — give award, share profile, report user |
| `/partials/dropdowns/notifications/items/` | 17 | ~1,700 | Template — hardcoded notification items |

**Total template bloat: ~370 files, ~33,000 lines — do not rebuild any of this.**

---

## Rebuild Approach

### Phase 1: Scaffold + Auth + Layout (1 day)
- New Vite + React project (or Next.js if preferred)
- Tailwind + shadcn/ui
- Clerk auth integration
- Sidebar nav + layout shell
- TanStack Query client with Clerk token

### Phase 2: Read-Only Pages (2-3 days)
- Shared `<DataTable>` component (TanStack Table + shadcn)
- Shared `<ReportPage>` component (date range + chart + table)
- Build all 22 simple pages (they're all the same pattern)
- Dashboard with chart cards

### Phase 3: Medium CRUD Pages (2-3 days)
- Shared `<CrudPage>` component (table + add/edit/delete modals)
- Driver list, accounts, POI, tariffs, availability
- Booking action pages (dispatch, amendments, accept/reject)
- Credit/billing view pages

### Phase 4: Complex Pages (3-5 days)
- Invoice Processor (multi-step workflow)
- Statement Processing (multi-step workflow)
- New Booking Form (address lookup + pricing)
- Invoice Processor Groups
- Driver Tracking (GPS map)

### Phase 5: Polish + Test (1-2 days)
- Role-based route protection
- Error boundaries
- Playwright e2e tests for critical flows
- Responsive design pass

**Total estimate: 9-14 days for a complete rebuild.**

---

*This inventory is for planning. Do not implement until PRD v2 is approved.*
