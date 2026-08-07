# Red Taxi — PRD v2c: v2 API Completion

**Version:** 1.1
**Status:** COMPLETE — 175+ v2 endpoints, all V2 controllers routing-only
**Author:** Red Banana Studios
**Created:** 2026-03-29
**Updated:** 2026-04-03
**Depends on:** PRD v1.2 (complete), shared-contract-roles.md
**Parallel with:** PRD v2a (auth), PRD v2b (admin rebuild), PRD v2d (dispatch auth)
**Blocked by:** Nothing — can start day 1

> This PRD can be executed by a Codex agent. It is backend-only.
> Every endpoint follows the same pattern: existing MediatR handler → new v2
> controller route → `{ success, data, errors }` envelope → snapshot test.
> No new business logic.

---

## 1. Objective

Create the ~60 missing v2 API endpoints that the admin frontend rebuild (PRD v2b)
needs. The v1 handlers already exist — this work is purely adding v2 routes with
the standard envelope format.

### Why this is separate from v2a and v2b
- v2a touches auth middleware/services — completely different files
- v2b is frontend-only — needs these endpoints to exist
- This is mechanical backend work: one controller, one route, one test per endpoint
- A Codex agent can churn through these with minimal context

### What this does NOT do
- Does not create new business logic — handlers already exist
- Does not change v1 routes — they continue working
- Does not touch auth (that's v2a)
- Does not touch frontend (that's v2b)

---

## 2. Driver-Context Pattern

**Critical pattern that applies to many endpoints.**

Most admin pages have a "driver dropdown" — admin selects a driver to view/edit
their data. When a driver is logged in, they see only their own data with no
dropdown.

### How it works in v1
- Admin calls: `/api/AdminUI/DriverExpenses?userId=42`
- Driver calls: `/api/AdminUI/DriverExpenses?userId=7` (their own ID)
- No backend enforcement — the frontend just passes the right ID

### How v2 endpoints must work

```
GET /api/v2/drivers/{driverId}/expenses     — Admin: any driverId
GET /api/v2/drivers/me/expenses             — Driver: own data only (enforced)
```

Or with query param approach (simpler, consistent with v1):

```
GET /api/v2/availability?driverId=42        — Admin: explicit driver
GET /api/v2/availability                    — Driver: defaults to self (from HttpContext)
```

### Implementation rule

Every endpoint that takes a `driverId` or `userId` parameter must:

1. Read `UserRole` from `HttpContext.Items["UserRole"]`
2. Read `UserId` from `HttpContext.Items["UserId"]`
3. If role is Driver:
   - Ignore any `driverId` parameter
   - Force `driverId = UserId` (prevent drivers viewing other drivers' data)
4. If role is Admin or User:
   - Use provided `driverId` parameter
   - Return 400 if `driverId` not provided (admin must specify which driver)
5. Log the effective driverId in structured logging

```csharp
// Standard pattern for driver-context endpoints
var effectiveDriverId = GetEffectiveDriverId(request.DriverId, HttpContext);

private int GetEffectiveDriverId(int? requestedDriverId, HttpContext context)
{
    var role = context.Items["UserRole"]?.ToString();
    var userId = (int)context.Items["UserId"];

    if (role == "Driver")
        return userId; // Drivers always see own data

    if (requestedDriverId == null || requestedDriverId == 0)
        throw new ArgumentException("driverId required for admin/user role");

    return requestedDriverId.Value;
}
```

**This helper should be extracted to a shared base class or extension method** —
it will be used by 15+ endpoints.

---

## 3. Notification Replacement: Browser FCM → Pusher

### Current state
- Browser FCM tokens stored in `ChromeFCM` column on `AppUserProfiles`
- `UpdateBrowserFCM` / `RemoveBrowserFCM` endpoints manage tokens
- FCM sends browser push for: driver reject/timeout, web booking notifications
- Works poorly — unreliable delivery, complex token management
- `NotificationFCM` column is for **driver app mobile push** — NOT being replaced

### Target state
- **Remove browser FCM entirely** — delete `ChromeFCM` column, remove
  `UpdateBrowserFCM` / `RemoveBrowserFCM` endpoints
- **Replace with Pusher events** — already tenant-scoped (PR #4)
- Browser shows notification via `Notification` API when Pusher event received
- Audio alerts: different sound per event group, on/off toggle, stored in
  browser `localStorage` (already per-browser, just formalise it)

### What changes in v2c

**Do NOT create v2 endpoints for:**
- `UpdateBrowserFCM` — removed
- `RemoveBrowserFCM` — removed
- `GetSMSHeartBeat` — replaced with Pusher connection health

**DO create:**
- `GET /api/v2/notifications/settings` — returns notification event groups + current on/off state
- `PUT /api/v2/notifications/settings` — saves per-user notification preferences (which event groups to receive)

**Pusher event groups for browser notifications:**

| Event group | Pusher event name | Sound | Description |
|------------|-------------------|-------|-------------|
| `driver_reject` | `booking.driver-rejected` | Alert tone | Driver rejected allocated booking |
| `driver_timeout` | `booking.driver-timeout` | Alert tone | Driver didn't respond in time |
| `web_booking` | `booking.web-new` | Chime | New web booking received |
| `web_change` | `booking.web-change-request` | Chime | Web booking change request |
| `booking_cancelled` | `booking.cancelled` | Warning tone | Booking cancelled |

Audio settings are **frontend-only** (localStorage) — no backend endpoint needed.

### Keep untouched
- `NotificationFCM` column — driver app mobile push, separate concern
- `UpdateFCM` endpoint (for driver app) — stays as-is
- Pusher event publishing in existing handlers — already works

---

## 4. Endpoint Inventory

### Standard v2 Pattern

Every endpoint follows this pattern:

```csharp
// Controller (routing only)
[HttpGet]
public async Task<IActionResult> GetDrivers()
    => (await _mediator.Send(new ListDrivers.Query()))
        .ToActionResult();

// Extension method for Result<T> → v2 envelope
public static IActionResult ToActionResult<T>(this Result<T> result)
    => result.IsSuccess
        ? new OkObjectResult(new { success = true, data = result.Value, errors = Array.Empty<string>() })
        : new BadRequestObjectResult(new { success = false, data = (object?)null, errors = result.Errors });
```

---

### Priority 1: Core Admin (12-15 hours)

#### Drivers Controller — `Controllers/V2/DriversController.cs`

| Method | Route | v1 Source | Handler | Driver-context? | Notes |
|--------|-------|-----------|---------|----------------|-------|
| GET | `/api/v2/drivers` | `/api/AdminUI/DriversList` | `ListDrivers` | No (admin-only page) | Returns all drivers for tenant |
| POST | `/api/v2/drivers` | `/api/AdminUI/DriverAdd` | `DriverAdd` | No | Creates user + profile + Clerk invite (post-v2a) |
| PUT | `/api/v2/drivers/{id}` | `/api/AdminUI/DriverUpdate` | `DriverUpdate` | No | Updates driver details |
| DELETE | `/api/v2/drivers/{id}` | `/api/AdminUI/DriverDelete` | `DriverDelete` | No | Soft delete |
| POST | `/api/v2/drivers/{id}/lockout` | `/api/AdminUI/DriverLockout` | `DriverLockout` | No | Toggle lockout |
| POST | `/api/v2/drivers/{id}/show-all-jobs` | `/api/AdminUI/DriverShowAllJobs` | `DriverShowAllJobs` | No | Toggle visibility |
| POST | `/api/v2/drivers/{id}/show-hvs-jobs` | `/api/AdminUI/DriverShowHVSJobs` | `DriverShowHVSJobs` | No | Toggle visibility |
| POST | `/api/v2/drivers/{id}/resend-login` | `/api/AdminUI/DriverResendLogin` | `DriverResendLogin` | No | Re-send Clerk invitation (post-v2a) |
| GET | `/api/v2/drivers/{id}/expiry` | `/api/AdminUI/GetDriverExpirys` | `GetDriverExpirys` | No | Document expiry dates |
| PUT | `/api/v2/drivers/{id}/expiry` | `/api/AdminUI/UpdateDriverExpiry` | `UpdateDriverExpiry` | No | Update expiry dates |
| GET | `/api/v2/drivers/gps` | `/api/UserProfile/GetAllGPS` | `GetAllUsersGPS` | No (admin-only) | All driver positions |

#### Dashboard Controller — `Controllers/V2/DashboardController.cs`

| Method | Route | v1 Source | Handler | Notes |
|--------|-------|-----------|---------|-------|
| GET | `/api/v2/dashboard/stats` | `/api/AdminUI/Dashboard` | `GetDashboard` | KPI cards data |

#### POI Controller — `Controllers/V2/PoisController.cs`

| Method | Route | v1 Source | Handler | Notes |
|--------|-------|-----------|---------|-------|
| GET | `/api/v2/pois` | `/api/AdminUI/GetPOIs` | `GetPOIs` | All POIs |
| POST | `/api/v2/pois` | `/api/AdminUI/AddPOI` | `AddPOI` | Create POI |
| PUT | `/api/v2/pois/{id}` | `/api/AdminUI/UpdatePOI` | `UpdatePOI` | Update POI |
| DELETE | `/api/v2/pois/{id}` | `/api/AdminUI/DeletePOI` | `DeletePOI` | Delete POI |

#### Availability Controller — `Controllers/V2/AvailabilityController.cs`

| Method | Route | v1 Source | Handler | Driver-context? | Notes |
|--------|-------|-----------|---------|----------------|-------|
| GET | `/api/v2/availability` | `/api/AdminUI/GetAvailability` | `GetUserAvailability` | **Yes** | `?driverId=X&date=Y` |
| POST | `/api/v2/availability` | `/api/AdminUI/SetAvailability` | `SetUserAvailability` | **Yes** | Set availability slot |
| DELETE | `/api/v2/availability/{id}` | `/api/AdminUI/DeleteAvailability` | `DeleteAvailability` | **Yes** | Remove slot |
| GET | `/api/v2/availability/log` | `/api/AdminUI/AvailabilityLog` | `GetAvailabilityLog` | **Yes** | `?driverId=X&date=Y` |
| GET | `/api/v2/availability/report` | `/api/AdminUI/AvailabilityReport` | `GetAvailabilityReport` | No | Aggregate report |

#### Settings Controller — `Controllers/V2/SettingsController.cs`

| Method | Route | v1 Source | Handler | Notes |
|--------|-------|-----------|---------|-------|
| GET | `/api/v2/settings/company` | `/api/AdminUI/GetCompanyConfig` | `GetCompanyConfig` | Company details |
| PUT | `/api/v2/settings/company` | `/api/AdminUI/UpdateCompanyConfig` | `UpdateCompanyConfig` | Update company |
| GET | `/api/v2/settings/messaging` | `/api/AdminUI/GetMessageConfig` | `GetMessageConfig` | SMS/WhatsApp config |
| PUT | `/api/v2/settings/messaging` | `/api/AdminUI/UpdateMessageConfig` | `UpdateMessageConfig` | Update messaging |

#### Bookings Controller (additions) — `Controllers/V2/BookingsController.cs`

| Method | Route | v1 Source | Handler | Notes |
|--------|-------|-----------|---------|-------|
| GET | `/api/v2/bookings/by-status` | `/api/AdminUI/BookingsByStatus` | `GetBookingsByStatus` | `?date=&scope=&status=` |
| GET | `/api/v2/bookings/{id}/audit` | `/api/AdminUI/BookingAudit` | `GetBookingAudit` | Admin-only (role check) |
| GET | `/api/v2/bookings/airport-runs` | `/api/AdminUI/AirportRuns` | `GetAirportRuns` | Read-only list |
| GET | `/api/v2/bookings/turndowns` | `/api/AdminUI/GetTurndowns` | `GetTurndowns` | Read-only list |
| GET | `/api/v2/bookings/card-bookings` | `/api/AdminUI/CardBookings` | `GetCardBookings` | Admin-only |
| POST | `/api/v2/bookings/cancel-range` | `/api/AdminUI/CancelBookingsInRange` | `CancelBookingsInRange` | Admin-only, bulk |
| GET | `/api/v2/bookings/cancel-range-report` | `/api/AdminUI/CancelBookingsInRangeReport` | `GetCancelRangeReport` | Admin-only |
| POST | `/api/v2/bookings/{id}/send-card-reminder` | `/api/AdminUI/SendCardPaymentReminder` | `SendCardPaymentReminder` | Admin-only |
| POST | `/api/v2/bookings/{id}/restore` | `/api/Bookings/RestoreCancelled` | `RestoreCancelled` | Restore cancelled booking |

---

### Priority 2: Billing (10-12 hours)

#### Billing Controller — `Controllers/V2/BillingController.cs`

**Driver Statements:**

| Method | Route | v1 Source | Handler | Driver-context? |
|--------|-------|-----------|---------|----------------|
| GET | `/api/v2/billing/driver/chargeable-jobs` | `/api/Accounts/DriverGetChargableJobs` | `DriverGetChargeableJobs` | **Yes** |
| PUT | `/api/v2/billing/driver/charges` | `/api/Accounts/DriverUpdateChargesData` | `DriverUpdateCharges` | **Yes** |
| POST | `/api/v2/billing/driver/post-jobs` | `/api/Accounts/DriverPostOrUnPostJobs` | `DriverPostJobs` | **Yes** |
| POST | `/api/v2/billing/driver/statements` | `/api/Accounts/DriverCreateStatments` | `CreateDriverStatements` | **Yes** |
| GET | `/api/v2/billing/driver/statements` | `/api/Accounts/DriverGetStatments` | `GetDriverStatements` | **Yes** |
| POST | `/api/v2/billing/driver/statements/{id}/resend` | `/api/Accounts/ResendDriverStatement` | `ResendDriverStatement` | No |
| POST | `/api/v2/billing/driver/statements/{id}/mark-paid` | `/api/Accounts/MarkStatementAsPaid` | `MarkStatementPaid` | No |
| POST | `/api/v2/billing/driver/price-by-mileage` | `/api/Bookings/GetPrice` | `PriceByMileage` | No |

**Account Invoices:**

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| GET | `/api/v2/billing/account/chargeable-jobs` | `/api/Accounts/AccountGetChargableJobs` | `AccountGetChargeableJobs` |
| GET | `/api/v2/billing/account/chargeable-jobs-grouped` | `/api/Accounts/AccountGetChargableJobsGrouped` | `AccountGetChargeableJobsGrouped` |
| GET | `/api/v2/billing/account/chargeable-jobs-grouped-split` | `/api/Accounts/AccountGetChargableJobsGroupedSplit` | `AccountGetChargeableJobsGroupedSplit` |
| PUT | `/api/v2/billing/account/charges` | `/api/Accounts/AccountUpdateChargesData` | `AccountUpdateCharges` |
| POST | `/api/v2/billing/account/post-jobs` | `/api/Accounts/AccountPostOrUnPostJobs` | `AccountPostJobs` |
| POST | `/api/v2/billing/account-driver/post-jobs` | `/api/Accounts/PostOrUnPostJobsAccountDriver` | `AccountDriverPostJobs` |
| POST | `/api/v2/billing/account/invoices` | `/api/Accounts/AccountCreateInvoice` | `CreateAccountInvoice` |
| POST | `/api/v2/billing/account/price-manually` | `/api/Accounts/AccountPriceManually` | `AccountPriceManually` |
| POST | `/api/v2/billing/account/price-by-mileage` | `/api/Accounts/AccountPriceJobByMileage` | `AccountPriceByMileage` |
| POST | `/api/v2/billing/account/price-bulk` | `/api/Accounts/PriceBulk` | `AccountPriceBulk` |

**Invoice Management:**

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| GET | `/api/v2/billing/invoices` | `/api/Accounts/GetInvoices` | `GetInvoices` |
| GET | `/api/v2/billing/invoices/{id}/download` | `/api/Accounts/DownloadInvoice` | `DownloadInvoice` |
| GET | `/api/v2/billing/invoices/{id}/csv` | `/api/Accounts/DownloadInvoiceCSV` | `DownloadInvoiceCsv` |
| POST | `/api/v2/billing/invoices/{id}/resend` | `/api/Accounts/ResendInvoice` | `ResendInvoice` |
| POST | `/api/v2/billing/invoices/{id}/mark-paid` | `/api/Accounts/MarkInvoiceAsPaid` | `MarkInvoicePaid` |
| DELETE | `/api/v2/billing/invoices/{id}` | `/api/Accounts/DeleteInvoice` | `DeleteInvoice` |
| POST | `/api/v2/billing/invoices/{id}/clear` | `/api/Accounts/ClearInvoice` | `ClearInvoice` |

**Credits:**

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| POST | `/api/v2/billing/invoices/{id}/credit` | `/api/Accounts/CreditInvoice` | `CreditInvoice` |
| POST | `/api/v2/billing/credit-journeys` | `/api/Accounts/CreditJourneys` | `CreditJourneys` |
| GET | `/api/v2/billing/credit-notes` | `/api/Accounts/GetCreditNotes` | `GetCreditNotes` |
| GET | `/api/v2/billing/credit-notes/{id}/download` | `/api/Accounts/DownloadCreditNote` | `DownloadCreditNote` |

**VAT:**

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| GET | `/api/v2/billing/vat-outputs` | `/api/Accounts/VATOutputs` | `GetVatOutputs` |

---

### Priority 3: Secondary Features (5-8 hours)

#### Web Bookings Controller — `Controllers/V2/WebBookingsController.cs`

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| GET | `/api/v2/web-bookings` | `/api/WeBooking/GetWebBookings` | `GetWebBookings` |
| POST | `/api/v2/web-bookings/{id}/accept` | `/api/WeBooking/Accept` | `AcceptWebBooking` |
| POST | `/api/v2/web-bookings/{id}/reject` | `/api/WeBooking/Reject` | `RejectWebBooking` |
| POST | `/api/v2/web-bookings/{id}/amend-accept` | `/api/WeBooking/AmendAccept` | `AmendAcceptWebBooking` |
| GET | `/api/v2/web-bookings/{id}/duration` | `/api/WeBooking/GetDuration` | `GetDuration` |
| GET | `/api/v2/web-bookings/change-requests` | `/api/AdminUI/GetWebChangeRequests` | `GetWebChangeRequests` |
| PUT | `/api/v2/web-bookings/change-requests/{id}` | `/api/AdminUI/UpdateWebChangeRequest` | `UpdateWebChangeRequest` |

#### Messaging Controller — `Controllers/V2/MessagingController.cs`

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| POST | `/api/v2/messaging/driver` | `/api/AdminUI/SendMessageToDriver` | `SendMessageToDriver` |
| POST | `/api/v2/messaging/broadcast` | `/api/AdminUI/SendMessageToAllDrivers` | `SendMessageToAllDrivers` |

#### Reporting Controller (additions) — `Controllers/V2/ReportingController.cs`

| Method | Route | v1 Source | Handler | Driver-context? |
|--------|-------|-----------|---------|----------------|
| GET | `/api/v2/reporting/driver-earnings` | `/api/AdminUI/DriverEarningsReport` | `GetDriverEarnings` | **Yes** |
| GET | `/api/v2/reporting/driver-expenses` | `/api/AdminUI/DriverExpenses` | `GetDriverExpenses` | **Yes** |

#### Notifications Controller (additions) — `Controllers/V2/NotificationsController.cs`

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| DELETE | `/api/v2/notifications/{id}` | `/api/AdminUI/ClearNotification` | `ClearNotification` |
| DELETE | `/api/v2/notifications` | `/api/AdminUI/ClearAllNotifications` | `ClearAllNotifications` |
| GET | `/api/v2/notifications/settings` | New | `GetNotificationSettings` |
| PUT | `/api/v2/notifications/settings` | New | `UpdateNotificationSettings` |

#### Utilities Controller — `Controllers/V2/UtilitiesController.cs`

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| POST | `/api/v2/utilities/hvs-account-move` | `/api/AdminUI/Move9014To10026` | `HvsAccountMove` |

#### Support Controller — `Controllers/V2/SupportController.cs`

| Method | Route | v1 Source | Handler |
|--------|-------|-----------|---------|
| POST | `/api/v2/support/ticket` | `/api/AdminUI/SubmitTicket` | `SubmitTicket` |

---

## 5. Endpoints NOT Being Created

| v1 Endpoint | Reason |
|-------------|--------|
| `UpdateBrowserFCM` | Removed — browser FCM replaced by Pusher |
| `RemoveBrowserFCM` | Removed — browser FCM replaced by Pusher |
| `GetSMSHeartBeat` | Replaced by Pusher connection health (frontend-only) |
| `UserProfile/Login` | Removed by v2a (Clerk handles login) |
| `UserProfile/Register` | Removed by v2a (Clerk handles registration) |
| `UserProfile/ResetPassword` | Removed by v2a (Clerk handles password reset) |
| `UserProfile/GetUser` | Replaced by `GET /api/v2/users/me` (v2a) |

---

## 6. Testing

Every new v2 endpoint gets a snapshot test:

```csharp
[Fact]
public Task GetDrivers() => VerifyGet("/api/v2/drivers");

[Fact]
public Task GetDriverExpiry() => VerifyGet("/api/v2/drivers/1/expiry");

[Fact]
public Task GetAvailability() => VerifyGet("/api/v2/availability?driverId=1&date=2026-01-01");
```

Expected test count increase: ~60 new snapshot tests.

---

## 7. Effort Summary

| Priority | Area | Endpoints | Effort |
|----------|------|----------|--------|
| 1 | Drivers, Dashboard, POI, Availability, Settings, Bookings | 28 | 12-15h |
| 2 | Billing (statements, invoices, credits, VAT) | 25 | 10-12h |
| 3 | Web bookings, Messaging, Reporting additions, Notifications, Utilities | 14 | 5-8h |
| | **Total** | **67** | **27-35h** |

---

## 8. Non-Negotiable Rules

- Every endpoint returns `{ success, data, errors }` envelope
- Every endpoint has a snapshot test
- Every endpoint has structured Serilog logging (Info on success, Warning on failure)
- Driver-context endpoints enforce role-based driverId resolution
- Role-gated endpoints (audit, cancel-range, card-bookings) check `HttpContext.Items["UserRole"]`
- No business logic changes — handlers are called exactly as v1 controllers call them
- No browser FCM endpoints — that system is being removed
- `NotificationFCM` (driver app mobile push) is NOT touched

---

## 9. Implementation Status (2026-04-03)

**150 v2 endpoints exist** across 23 controllers in two projects:
- **19 in RedTaxi.API** — all tenant product logic (bookings, drivers, billing workflows, reports)
- **4 in RedTaxi.Platform** — SaaS platform concerns (Billing/Stripe, TenantOnboarding, TenantStatus)

The original PRD scoped 67 endpoints; many more were created during the admin v2 build.

### Controllers built (23 total — 19 API + 4 Platform)

| Controller | Route Prefix | Endpoints | PRD Section |
|-----------|-------------|-----------|-------------|
| AccountsController | api/v2/accounts | 13 | Priority 1 (extended beyond PRD) |
| AvailabilityController | api/v2/availability | 7 | Priority 1 |
| BillingController | api/v2/billing | 3 | SaaS Stripe (not in PRD) |
| BookingsController | api/v2/bookings | 16 | Priority 1 |
| DashboardController | api/v2/dashboard | 1 | Priority 1 |
| DeliveryStatusController | api/v2/delivery-status | 2 | Not in PRD (webhooks) |
| DispatchController | api/v2/dispatch | 7 | Not in PRD (driver app) |
| DriversController | api/v2/drivers | 13 | Priority 1 |
| InvoiceProcessingController | api/v2/billing/invoices | 16 | Priority 2 |
| MarketingController | api/v2/marketing | 3 | Not in PRD (QR codes) |
| MessagingController | api/v2/messaging | 2 | Priority 3 |
| NotificationsController | api/v2/notifications | 5 | Priority 3 (partial) |
| POIController | api/v2/pois | 4 | Priority 1 |
| PricingController | api/v2/pricing | 5 | Pre-existing |
| ReportingController | api/v2/reporting | 18 | Priority 3 |
| SettingsController | api/v2/settings | 4 | Priority 1 |
| StatementProcessingController | api/v2/billing/statements | 9 | Priority 2 |
| StripeWebhookController | api/v2/stripe | 1 | SaaS (not in PRD) |
| TenantOnboardingController | api/v2/tenants | 3 | SaaS (not in PRD) |
| TenantStatusController | api/v2/tenant-status | 1 | SaaS (not in PRD) |
| UserProfileController | api/v2/users | 9 | Priority 3 (extended) |
| UtilitiesController | api/v2/utilities | 1 | Priority 3 |
| WebBookingsController | api/v2/web-bookings | 7 | Priority 3 |

### Route deviations from PRD

The PRD proposed routes that were implemented with different patterns:

| PRD Route | Actual Route | Reason |
|-----------|-------------|--------|
| `api/v2/billing/driver/*` | `api/v2/billing/statements/*` | Clearer naming — StatementProcessingController |
| `api/v2/billing/account/*` | `api/v2/billing/invoices/*` | Clearer naming — InvoiceProcessingController |
| `GET /api/v2/billing/invoices` | `POST /api/v2/billing/invoices/history` | POST with filter body |
| `GET /api/v2/billing/vat-outputs` | `POST /api/v2/accounts/vat-outputs` | Lives on AccountsController |
| `GET /api/v2/web-bookings` | `POST /api/v2/web-bookings/list` | POST with filter body |
| `GET /api/v2/reporting/driver-earnings` | `POST /api/v2/reporting/driver-earnings` | POST with date params |
| `GET /api/v2/reporting/driver-expenses` | `POST /api/v2/reporting/driver-expenses` | POST with date params |
| `GET /api/v2/notifications/settings` | `GET /api/v2/users/me/notification-preferences` | Lives on UserProfileController |
| `PUT /api/v2/notifications/settings` | `PUT /api/v2/users/me/notification-preferences` | Lives on UserProfileController |

### Endpoints genuinely missing (5)

| Endpoint | Reason Not Built |
|----------|-----------------|
| `POST /api/v2/drivers/{id}/resend-login` | Blocked by v2a — needs Clerk invitation API |
| `GET /api/v2/bookings/by-status` | Not needed — dashboard stats + search cover this |
| `POST /api/v2/bookings/{id}/send-card-reminder` | Card booking page doesn't have this action |
| `GET /api/v2/web-bookings/{id}/duration` | Frontend calculates duration client-side |
| `POST /api/v2/support/ticket` | No UI for support tickets — SupportController not created |

### Endpoints removed (as planned)

| Endpoint | Status |
|----------|--------|
| UpdateBrowserFCM | Removed — Pusher replaces browser FCM |
| RemoveBrowserFCM | Removed — Pusher replaces browser FCM |
| GetSMSHeartBeat | Removed — Pusher connection health is frontend-only |
| Login/Register/ResetPassword | Removed by v2a — Clerk handles auth |

### Endpoints added beyond PRD scope (not originally planned)

| Controller | Endpoints | Purpose |
|-----------|-----------|---------|
| InvoiceProcessingController | 16 | Full invoice + credit workflow |
| StatementProcessingController | 9 | Full statement workflow |
| MarketingController | 3 | QR code CRUD + scan tracking |
| DispatchController | 7 | Driver app dispatch operations |
| DeliveryStatusController | 2 | SMS/email delivery webhooks |
| TenantOnboardingController | 3 | SaaS tenant provisioning |
| UserProfileController (extended) | 4 | Profile, notification preferences |
| AccountsController (extended) | 6 | Booker management, delete checks, VAT |

---

*This document was originally a draft. Updated 2026-04-03 to reflect actual implementation status.
150 v2 endpoints across 23 controllers. Original scope of 67 has been exceeded.*
