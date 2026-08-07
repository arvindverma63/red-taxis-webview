# Red Taxi — PRD v2b: Admin Frontend Rebuild

**Version:** 1.1
**Status:** COMPLETE — 58 dashboard routes live (54 sidebar-exposed + 4 non-nav), /dispatch embeds headless-dispatch via iframe
**Author:** Red Banana Studios
**Created:** 2026-03-29
**Updated:** 2026-04-07
**Depends on:** PRD v1.2 (complete), SaaS backend (complete)
**Parallel with:** PRD v2a (Auth Consolidation)

> This PRD can be executed by a Codex agent or Replit. It is frontend-only.
> It does NOT touch the backend except to identify missing v2 API endpoints
> that must be created as a dependency.

---

## 1. Objective

Replace the current admin frontend (88,164 lines across 1,108 files, built on a
purchased UI template) with a clean, purpose-built admin app (~15,000 lines,
~120 files) using a modern stack.

### Why rebuild vs. iterate
- **60% of the codebase is unused template bloat** — social profiles, NFT cards,
  notification items 1-17, team management pages that have nothing to do with taxi dispatch
- **4 styling systems** fighting each other (MUI, Emotion, Tailwind, styled-components)
- **Zero tests** — no safety net for changes
- **All v1 API** — none of the 135 endpoints use the v2 envelope format
- **Legacy JWT auth** — would need replacing anyway (PRD v2a)
- **The actual taxi admin is ~35 pages** — most are simple table + fetch patterns.
  Building from scratch is faster than untangling the template.

### What this does NOT do
- Does not change any backend logic or API response shapes
- Does not touch the dispatch app (separate, real-time, complex — leave it alone)
- Does not touch the driver app
- Does not change database schema

---

## 2. Current State

### Admin App Metrics
| Metric | Value |
|--------|-------|
| Total source files | 1,108 |
| Total lines of code | 88,164 |
| Active routes | ~45 |
| Template bloat (unused) | ~370 files, ~33,000 lines |
| Styling systems | 4 (MUI, Emotion, Tailwind, styled-components) |
| Auth | Custom JWT in localStorage, Redux authSlice |
| State management | Redux Toolkit (12 slices, 1,667 lines) |
| API layer | 13 service files (3,049 lines), all v1 endpoints |
| Tests | Zero |

### Page Complexity Breakdown
| Complexity | Count | Description |
|-----------|-------|-------------|
| Simple | 22 | Read-only tables, reports, history views |
| Medium | 18 | CRUD forms, data tables with actions |
| Complex | 5 | Multi-step workflows, maps, calculations |
| **Total** | **45** | |

See `docs/admin-rebuild-inventory.md` for the full page-by-page inventory.

---

## 3. Target Stack

| Concern | Choice | Rationale |
|---------|--------|-----------|
| Framework | Vite + React 18 (or Next.js if SSR needed) | Same framework family, fast builds |
| Styling | Tailwind CSS + shadcn/ui | One system, accessible, composable |
| Data fetching | TanStack Query v5 | Server state belongs in cache, not Redux |
| Tables | TanStack Table v8 + shadcn DataTable | Already proven, headless, sortable/filterable |
| Forms | React Hook Form + Zod | Lighter than Formik + Yup, better TS support |
| Charts | Recharts (or keep ApexCharts) | Simpler API, React-native |
| Maps | React-Leaflet | Keep for driver tracking + POI |
| Auth | Clerk React SDK | `<SignIn />`, `useAuth()`, `<OrganizationSwitcher />` |
| Routing | React Router v6 (or Next.js App Router) | Familiar, proven |
| PDF | jsPDF + jsPDF-Autotable | Keep existing approach |
| Notifications | Sonner | One toast library, not three |
| Testing | Playwright e2e | Cover critical flows |

### What we're removing
- Redux Toolkit (12 slices) → TanStack Query handles server state
- MUI + Emotion + styled-components → Tailwind + shadcn/ui only
- Auth0 SDK (unused) → removed
- Firebase SDK → removed (FCM handled by backend)
- React Query v3 (legacy, unused) → TanStack Query v5
- Notistack + React Hot Toast → Sonner only
- react-intl (i18n) → defer unless multi-language actually needed
- @faker-js/faker → removed (dev/demo data)

---

## 4. API Dependency — Missing v2 Endpoints

**Critical finding:** Only 19 of 135 admin endpoints have v2 equivalents.

The admin rebuild CANNOT ship without v2 endpoints for the remaining features.
These must be created as backend work (can be done by a separate Codex agent).

### v2 Endpoints That Already Exist (19)
| Area | Endpoints | Status |
|------|----------|--------|
| Accounts CRUD | GET/POST/PUT/DELETE /api/v2/accounts | ✅ Ready |
| Tariffs | GET/PUT /api/v2/accounts/tariffs | ✅ Ready |
| Bookings cancel | POST /api/v2/bookings/cancel | ✅ Ready |
| Dispatch allocate | POST /api/v2/dispatch/allocate | ✅ Ready |
| Pricing | POST /api/v2/pricing/* (3 endpoints) | ✅ Ready |
| Reporting | 13 report endpoints in /api/v2/reporting/* | ✅ Ready |
| Notifications | GET /api/v2/notifications | ✅ Ready |
| User login | POST /api/v2/users/login | ✅ Ready (removed by v2a) |

### v2 Endpoints That Need Creating (~60 endpoints across 10 areas)

**Priority 1 — Core admin functionality:**

| Area | Endpoints needed | v1 source | Est. |
|------|-----------------|-----------|------|
| **Dashboard** | GET /api/v2/dashboard/stats | /api/AdminUI/Dashboard | 1h |
| **Driver CRUD** | GET/POST/PUT/DELETE /api/v2/drivers | /api/AdminUI/Drivers* | 2h |
| **Driver expiry** | GET/PUT /api/v2/drivers/{id}/expiry | /api/AdminUI/*DriverExpiry* | 1h |
| **Driver settings** | POST /api/v2/drivers/{id}/lockout, /show-all-jobs, /show-hvs-jobs | /api/AdminUI/Driver* | 1h |
| **Booking views** | GET /api/v2/bookings/by-status, /audit, /card-bookings, /airport-runs, /turndowns | /api/AdminUI/* | 2h |
| **Booking actions** | POST /api/v2/bookings/cancel-range, /restore | /api/AdminUI/Cancel*, /api/Bookings/Restore* | 1h |
| **POI CRUD** | GET/POST/PUT/DELETE /api/v2/pois | /api/AdminUI/*POI* | 1h |
| **Availability** | GET/POST/DELETE /api/v2/availability, /log, /report | /api/AdminUI/*Availability* | 2h |
| **Settings** | GET/PUT /api/v2/settings/company, /api/v2/settings/messaging | /api/AdminUI/*Config | 1h |
| **Users/me** | GET /api/v2/users/me (current user + role) | New endpoint | 30m |

**Priority 2 — Billing (complex, most effort):**

| Area | Endpoints needed | v1 source | Est. |
|------|-----------------|-----------|------|
| **Driver statements** | GET/POST /api/v2/billing/driver/chargeable-jobs, /statements, /post-jobs | /api/Accounts/Driver* | 3h |
| **Account invoices** | GET/POST /api/v2/billing/account/chargeable-jobs, /invoices, /post-jobs | /api/Accounts/Account* | 3h |
| **Invoice groups** | GET /api/v2/billing/account/chargeable-jobs-grouped | /api/Accounts/AccountGetChargableJobsGrouped* | 1h |
| **Invoice history** | GET /api/v2/billing/invoices, /download, /csv | /api/Accounts/GetInvoices, /Download* | 2h |
| **Credit notes** | GET/POST /api/v2/billing/credit-notes, /credit-invoice, /credit-journeys | /api/Accounts/Credit* | 2h |
| **VAT** | GET /api/v2/billing/vat-outputs | /api/Accounts/VATOutputs | 30m |

**Priority 3 — Secondary features:**

| Area | Endpoints needed | v1 source | Est. |
|------|-----------------|-----------|------|
| **Web bookings** | GET/POST /api/v2/web-bookings, /accept, /reject, /amend | /api/WeBooking/* | 2h |
| **Change requests** | GET/PUT /api/v2/web-bookings/change-requests | /api/AdminUI/GetWebChangeRequests | 1h |
| **GPS tracking** | GET /api/v2/drivers/gps | /api/UserProfile/GetAllGPS | 30m |
| ~~FCM management~~ | ~~POST/DELETE /api/v2/notifications/browser-fcm~~ | ~~removed~~ | ~~0~~ | *Removed — browser FCM replaced by Pusher (see PRD v2c Section 3)* |
| **Driver messaging** | POST /api/v2/messaging/driver, /broadcast | /api/AdminUI/SendMessage* | 1h |
| **Driver earnings** | GET /api/v2/reporting/driver-earnings | /api/AdminUI/DriverEarningsReport | 30m |
| **Driver expenses** | GET /api/v2/reporting/driver-expenses | /api/AdminUI/DriverExpenses | 30m |
| **HVS account changes** | POST /api/v2/utilities/hvs-account-move | /api/AdminUI/Move9014To10026 | 30m |
| ~~SMS heartbeat~~ | ~~GET /api/v2/health/sms~~ | ~~removed~~ | ~~0~~ | *Removed — replaced by Pusher connection health (frontend-only)* |
| **Ticket submission** | POST /api/v2/support/ticket | /api/AdminUI/SubmitTicket | 30m |

**Total backend effort for v2 endpoints: ~25-30 hours**

All new v2 endpoints follow the existing pattern:
- Handler in `Features/{Area}/{UseCaseName}.cs`
- Route in `Controllers/V2/{Area}Controller.cs`
- Standard `{ success, data, errors }` envelope
- Structured Serilog logging
- Snapshot test

---

## 5. Implementation Plan

### Phase 1: Scaffold (Day 1)

**Step 1.1 — Project setup**
- New Vite + React project at `src/frontend/apps/admin-v2/`
- Tailwind CSS + shadcn/ui init
- TanStack Query client configured
- React Router with layout shell
- Vercel config (root dir, build command)

**Step 1.2 — Auth integration**
- Clerk React SDK: `<ClerkProvider>`, `<SignIn />`, `<SignUp />`
- Protected route wrapper using `useAuth()`
- API client with automatic Clerk token injection:
  ```typescript
  const api = axios.create({ baseURL: import.meta.env.VITE_API_URL });
  api.interceptors.request.use(async (config) => {
    const token = await getToken();
    config.headers.Authorization = `Bearer ${token}`;
    return config;
  });
  ```

**Step 1.3 — Layout shell**
- Sidebar navigation (collapsible)
- Top bar with `<UserButton />` and `<OrganizationSwitcher />`
- Role-based menu items (Admin sees everything, User sees restricted set)
- Breadcrumbs
- Mobile responsive

**Step 1.4 — Shared components**
- `<DataTable>` — wrapper around TanStack Table + shadcn Table
  - Column sorting, filtering, pagination
  - Row selection for bulk actions
  - Export to CSV
- `<ReportPage>` — date range selector + chart + data table
- `<CrudPage>` — data table + add/edit/delete modals
- `<FormModal>` — modal with React Hook Form + Zod validation
- `<PageHeader>` — title + breadcrumb + action buttons
- `<StatCard>` — metric card for dashboard

---

### Phase 2: Read-Only Pages (Days 2-4)

All 22 simple pages follow the same pattern. Build the shared components once,
then each page is just configuration:

```typescript
// Example: Airport Runs page — the entire page is this
export function AirportRunsPage() {
  return (
    <DataPage
      title="Airport Runs"
      endpoint="/api/v2/bookings/airport-runs"
      columns={airportRunsColumns}
    />
  );
}
```

**Pages to build (grouped by shared pattern):**

**Dashboard:**
- [ ] Dashboard home — stat cards + charts

**Reports (13 pages — all identical pattern):**
- [ ] Duplicate Bookings, Count by Scope, Top Customer, Growth by Period
- [ ] Pickups by Postcode, By Vehicle Type, Average Duration
- [ ] Payouts by Month, Revenue by Month, Profitability on Invoice
- [ ] Total Profitability by Period, Profitability by Date Range, QR Scans

**Read-only lists:**
- [ ] Turndown Bookings, Airport Runs
- [ ] Audit View (booking change history)
- [ ] Cancel by Range Report
- [ ] Availability Logs, Availability Report
- [ ] Statement History, Invoice History, VAT Outputs
- [ ] Driver Expenses, Driver Earning Report

---

### Phase 3: Medium CRUD Pages (Days 5-7)

**Driver Management:**
- [ ] Driver list — table + add/edit/delete modals
- [ ] Driver expiry — document tracking with date pickers
- [ ] Driver tracking — Leaflet map with GPS markers (10-sec polling)

**Account Management:**
- [ ] Account list — table + add/edit/delete modals
- [ ] Account tariffs — per-account pricing overrides

**Booking Management:**
- [ ] Booking dispatch — status table with allocate action
- [ ] Amendment bookings — review + accept/reject
- [ ] Accepted/Rejected bookings — lists with actions
- [ ] Card bookings — table + send payment reminder
- [ ] Cancel by range — date picker + bulk action
- [ ] Global search — search across all bookings

**Other CRUD:**
- [ ] POI list — table + map display + CRUD
- [ ] Availability management — set/delete driver slots
- [ ] Company settings — form
- [ ] Message settings — form
- [ ] HVS account changes — bulk action
- [ ] Credit invoices, credit journeys, credit notes

---

### Phase 4: Complex Pages (Days 8-12)

The 5 pages that need real attention:

**4.1 — Invoice Processor** (currently 2,144 lines)
- Multi-step workflow: load unbilled journeys → calculate by mileage → apply pricing → generate invoice
- Heavy table with inline editing
- Bulk select + price operations
- PDF generation (jsPDF)
- Target: 800-1000 lines with modern patterns
- Consider splitting into step components: `<SelectJobs>` → `<PriceJobs>` → `<GenerateInvoice>`

**4.2 — Statement Processing** (currently 1,869 lines)
- Multi-step: select driver → load jobs → price → post statement
- Mileage-based pricing calculations
- Target: 600-800 lines
- Same step-component pattern as invoice processor

**4.3 — New Booking Form** (currently 969 lines)
- Address autocomplete (Google Places API)
- Vehicle type selection
- Real-time pricing calculation
- Passenger details + notes
- Target: 400-500 lines with React Hook Form

**4.4 — Invoice Processor Groups** (currently 813+ lines per sub-page)
- Shared vs Singles grouping
- Priced vs Not-priced split
- Reuse pricing components from 4.1
- Target: 500-600 lines total

**4.5 — Driver Tracking** (currently 681 lines)
- Real-time GPS map (10-sec polling via TanStack Query `refetchInterval`)
- React-Leaflet with driver markers
- Status colours by driver state
- Target: 300-400 lines

---

### Phase 5: Polish + Deploy (Days 13-14)

- [ ] Role-based route protection (Admin vs User)
- [ ] Error boundaries with fallback UI
- [ ] Loading skeletons (shadcn Skeleton)
- [ ] Empty states for tables
- [ ] Mobile responsive pass
- [ ] Playwright e2e tests for critical flows:
  - Login → dashboard → see stats
  - Driver list → add driver → verify in table
  - Invoice processor → price jobs → generate invoice
  - Booking search → find booking → view details
- [ ] Vercel deployment config
- [ ] Feature flag to switch traffic from old admin to new admin

---

## 6. Role-Based Access

See `docs/shared-contract-roles.md` for the full shared role contract.

Roles live in the **tenant DB** (`AspNetUserRoles` + `AppRoles`), not in Clerk.
Clerk owns identity (auth, passwords, MFA). The tenant DB owns roles (what you
can do in this tenant). The admin app serves Admin and User roles only.

Role comes from `GET /api/v2/users/me` (built by PRD v2a). The response includes
`role` (string), `roleId` (int), and `permissions` (explicit booleans).

**New code uses `permissions` — not magic role numbers:**

```typescript
// Old pattern (dispatch — keeping for backwards compat)
if (userRole !== 2) { showRoute(); }

// New pattern (admin rebuild — use this)
if (me.permissions.canManageDrivers) { showRoute(); }
```

| Feature area | Admin | User/Staff | Permission key |
|-------------|-------|------------|----------------|
| Dashboard | ✅ | ✅ | (always visible) |
| All bookings views | ✅ | ✅ | (always visible) |
| Booking audit | ✅ | ❌ | `canViewAudit` |
| Cancel by range | ✅ | ❌ | `canCancelBookings` |
| Card bookings | ✅ | ❌ | `canViewBilling` |
| Drivers | ✅ | ❌ | `canManageDrivers` |
| Accounts | ✅ | ❌ | `canManageAccounts` |
| Billing | ✅ | ❌ | `canViewBilling` |
| Tariffs | ✅ | ❌ | `canManageAccounts` |
| Reports (financial) | ✅ | ❌ | `canViewFinancialReports` |
| Reports (booking) | ✅ | ✅ | (always visible) |
| Settings | ✅ | ❌ | `canManageSettings` |
| Utilities | ✅ | ❌ | `canManageSettings` |

---

## 7. Migration Strategy

### Parallel deployment
1. Deploy new admin as `admin-v2.redtaxi.co.uk` (new Vercel project)
2. Test with Ace Taxis admin users
3. Once stable, update shell app routing: `/admin` → new admin
4. Keep old admin alive at `admin-legacy.redtaxi.co.uk` for 2 weeks
5. After 2 weeks with zero fallback usage, delete old admin

### Data migration
- None. The new admin hits the same v2 API, same database.
- No data migration needed.

### Rollback
- Revert shell routing: `/admin` → old admin Vercel URL
- Old admin still deployed, still works (v1 endpoints unchanged)

---

## 8. Effort Estimate

| Phase | Effort | Dependencies |
|-------|--------|-------------|
| Phase 1: Scaffold + auth + layout + shared components | 1-2 days | Clerk org exists |
| Phase 2: 22 read-only pages | 2-3 days | v2 endpoints for reports (exist) |
| Phase 3: 18 medium CRUD pages | 2-3 days | v2 endpoints for drivers, POI, availability, settings (need creating) |
| Phase 4: 5 complex pages | 3-5 days | v2 endpoints for billing (need creating) |
| Phase 5: Polish + deploy | 1-2 days | All pages working |
| **Total frontend** | **9-14 days** | |
| **Backend: missing v2 endpoints** | **25-30 hours** | Can run in parallel |

---

## 9. Acceptance Criteria

The admin rebuild is complete when:

- [ ] All 45 pages functional and matching current feature set
- [ ] Clerk auth working (sign in, sign out, org switch)
- [ ] Role-based access enforced (Admin vs User)
- [ ] All API calls use v2 endpoints with envelope format
- [ ] Zero references to MUI, Emotion, styled-components, or Redux
- [ ] Playwright e2e tests passing for 5 critical flows
- [ ] Deployed to Vercel
- [ ] Shell app routing updated
- [ ] Old admin users confirm feature parity
- [ ] Total codebase under 20,000 lines
- [ ] Single styling system (Tailwind + shadcn/ui)

---

## 10. Non-Negotiable Rules

All rules from PRD v1.2 carry forward. Additionally:

- No Redux — TanStack Query for server state, React state/context for local UI state
- No MUI — Tailwind + shadcn/ui only
- No v1 API calls — all endpoints must be v2 envelope format
- No localStorage for auth — Clerk manages tokens
- No inline styles — Tailwind utilities or shadcn component variants
- Every page must have a loading skeleton and empty state
- Tables must support sort, filter, and CSV export
- Forms must validate client-side (Zod) before submission

---

## 11. What to Delete After Migration

Once the new admin is confirmed stable (2 weeks):

```
src/frontend/apps/admin/          — entire directory (88,164 lines)
```

The old admin is replaced entirely. No files are shared between old and new.

---

## 12. Implementation Status (2026-04-03)

**The admin rebuild is 99% complete.** It was built using Next.js 16 + React 19
(not Vite as originally proposed) at `src/frontend/apps/admin-v2/`.

### What was built

| Phase | PRD Plan | Actual Status |
|-------|----------|---------------|
| Phase 1: Scaffold | Day 1 | COMPLETE — Next.js 16, Clerk, TanStack Query, shadcn/ui, Tailwind v4 |
| Phase 2: Read-only (22 pages) | Days 2-4 | COMPLETE — all reports, dashboards, history views |
| Phase 3: CRUD (18 pages) | Days 5-7 | COMPLETE — drivers, accounts, bookings, POIs, availability, settings, web bookings |
| Phase 4: Complex (5 pages) | Days 8-12 | COMPLETE — invoice processor, statement processing, invoice groups, tracking, credit notes |
| Phase 5: Polish + deploy | Days 13-14 | PARTIAL — polished, Vercel-ready, not yet deployed to production |

### Stack deviations from PRD

| PRD Proposed | Actually Used | Reason |
|-------------|--------------|--------|
| Vite + React 18 | Next.js 16 + React 19 | Better SSR, App Router, built-in optimisations |
| React Router v6 | Next.js App Router | Comes with Next.js |
| React-Leaflet | Google Maps API | Already integrated, better for taxi use case |
| Playwright e2e | Snapshot tests (backend) | 244 backend snapshot tests cover API contract |
| TanStack Table | Custom sortable tables | SortableTableHead + TablePagination — simpler for our needs |

### 50 routes live (all wired to real API data)

See `docs/admin-v2-progress.md` for the complete page inventory.

### Remaining

| Item | Status |
|------|--------|
| `/dispatch` page content | Placeholder — needs design |
| Role-based route protection | Not implemented — all users see all pages |
| Playwright e2e tests | Not written — backend snapshot tests provide coverage |
| Shell app routing switch | Not done — still at admin-v2 Vercel URL |
| Old admin deletion | Not done — v1 admin still live in production |

### Acceptance criteria status

- [x] All 45+ pages functional and matching current feature set (50 routes, exceeds target)
- [x] Clerk auth working (sign in, sign out, dev token fallback)
- [ ] Role-based access enforced (Admin vs User) — deferred
- [x] All API calls use v2 endpoints with envelope format
- [x] Zero references to MUI, Emotion, styled-components, or Redux
- [ ] Playwright e2e tests — not written
- [ ] Deployed to production Vercel
- [ ] Shell app routing updated
- [ ] Old admin users confirm feature parity
- [x] Total codebase well under 20,000 lines
- [x] Single styling system (Tailwind v4 + shadcn/ui)

---

*This document was originally a draft. Updated 2026-04-03 to reflect actual implementation status.*
