# Dispatch v2 — UI Rebuild on v2 API Routes (Design)

**Date:** 2026-06-10
**Branch:** `feature/dispatch-v2`
**Status:** Approved (goal-driven session)

## Goal

Recreate the dispatch console UI as a new app (`src/frontend/apps/dispatch-v2`) keeping **all
logic identical** to the existing `headless-dispatch` app — every event, redux flow, and key UI
behaviour stays exactly as it is. Two changes only:

1. **All API calls move to `/api/v2/*` routes** (the v2 `{success, data, errors}` envelope).
2. **The Syncfusion `ScheduleComponent` is replaced with a new in-house scheduler component.**
   The scheduler *items* keep their exact logic and programmatic styling (driver colours,
   soft-allocate dot pattern, allocated stripes, status badges, Card/ASAP markers, light/dark
   text, merge-mode affordances).

Constraints:
- **v1 UI and v1 routes are not touched.** `headless-dispatch` keeps working unchanged.
- v2 backend routes are **additive only**, thin routing-only controllers delegating to the
  **same MediatR handlers** the v1 routes use (identical business logic).
- Test-driven: vitest + Testing Library on the frontend; Verify snapshot/error-case tests on
  new backend endpoints.

## Architecture

### Frontend (`src/frontend/apps/dispatch-v2`)

Copy of `headless-dispatch` (Vite + React 18 + Redux Toolkit + MUI + Tailwind) with:

- **`src/utils/apiReq.js` rewritten against v2 routes.** This module is the app's single API
  boundary. Every exported function keeps its **name, signature, and return shape** — the v2
  envelope is unwrapped back to the v1-visible shape (`{...data, status: 'success'}` /
  `status: 'fail' | 'error'` on 4xx/5xx) so all slices/components stay byte-identical in logic.
- **`src/components/Scheduler/`** — new scheduler component (no Syncfusion):
  - `DispatchScheduler.jsx` — view switcher (Day | Agenda), header with date navigation
    (matches Syncfusion navigating event semantics).
  - `DayView.jsx` — 24h time-gutter grid, absolute-positioned events with overlap column
    layout, `scrollToTime` support, cell-click → `(startTime)`.
  - `AgendaView.jsx` — date-grouped list for search results (replaces Agenda view).
  - `EventItem.jsx` — renders one booking using `computeEventVisuals()`.
  - `eventVisuals.js` — **pure port of `onEventRendered`**: same colour selection
    (suggested driver / user / `#795548` fallback), same backgrounds (radial dot pattern for
    soft allocate, `repeating-linear-gradient(-40deg …)` for allocated status=1, solid
    otherwise), same badges (Unallocated/Suggested/Allocated/✓ Complete, Card by
    paymentStatus, ASAP dashed outline), same `isLightColor` text rules, same merge-mode
    cursor/opacity rules.
  - `layout.js` — pure slot/overlap-column math (testable).
- `pages/Scheduler.jsx` keeps all its state, redux wiring, toggles (Show Allocated/Completed,
  Availability, Merge Mode, Conf. SA), search/turndown/text-message modals, 10s refresh, and
  scroll-to (now − 2h) — only the `<ScheduleComponent>` is swapped for `<DispatchScheduler>`.
- `@syncfusion/*` dependencies and `VITE_SYNCFUSION_KEY` removed.
- AuthContext iframe path calls `GET /api/v2/users/by-username` (same `GetUser.Query`).

### Backend — additive v2 endpoints (same handlers as v1)

All thin routing-only (current-user resolution allowed), envelope via `ToActionResult` /
`ToCommandResult`. v1→v2 map used by the app:

| v1 (unchanged) | v2 (new ➕ / existing ✔) | Handler |
|---|---|---|
| POST /api/Bookings/Create | ✔ POST /api/v2/bookings | CreateBooking |
| POST /api/Bookings/Update | ✔ PUT /api/v2/bookings | UpdateBooking |
| POST /api/Bookings/Cancel | ✔ POST /api/v2/bookings/cancel | CancelBooking |
| POST /api/Bookings/DateRange | ✔ GET /api/v2/bookings?from&to | GetBookings |
| GET /api/Bookings/FindById | ✔ GET /api/v2/bookings/{id} | GetBooking |
| POST /api/Bookings/FindBookings | ✔ POST /api/v2/bookings/search | FindBookings |
| POST /api/Bookings/Allocate | ✔ POST /api/v2/dispatch/allocate | AllocateBooking |
| POST /api/Bookings/SoftAllocate | ➕ POST /api/v2/dispatch/soft-allocate | SoftAllocate |
| POST /api/Bookings/ConfirmAllSoftAllocates | ➕ POST /api/v2/dispatch/soft-allocate/confirm-all | SoftAllocateConfirmAll + AllocateBooking loop (mirrors v1) |
| POST /api/Bookings/Complete | ➕ POST /api/v2/bookings/complete | CompleteJob (id/isAdmin from HttpContext like v1) |
| POST /api/Bookings/GetPrice | ➕ POST /api/v2/pricing/quote | GetSchoolContractPrice / GetCashPrice / GetInvoicePrice (v1 account routing moved as-is — flagged: conditional in controller mirrors legacy v1 GetPrice verbatim) |
| GET /api/Bookings/GetDuration | ➕ GET /api/v2/bookings/duration | GetDuration |
| GET /api/Bookings/MergeBookings | ➕ POST /api/v2/bookings/merge | MergeBookings |
| GET /api/Bookings/RecordTurnDown | ➕ POST /api/v2/bookings/turndown | RecordTurnDown |
| POST /api/Bookings/CreateCOAEntry | ➕ POST /api/v2/bookings/coa | RecordCOAEntry |
| GET /api/Bookings/GetCOAEntrys | ➕ GET /api/v2/bookings/coa | GetCOAEntrys |
| GET /api/Bookings/GetActionLogs | ✔ GET /api/v2/bookings/action-logs | GetActionLogs |
| GET /api/Bookings/SendConfirmationText | ➕ POST /api/v2/bookings/{id}/confirmation-text | SendConfirmationText |
| GET /api/Bookings/PaymentLink | ➕ POST /api/v2/bookings/{id}/payment-link | SendPaymentLink |
| GET /api/Bookings/ReminderPaymentLink | ➕ POST /api/v2/bookings/{id}/payment-reminder | ResendPaymentLink |
| GET /api/Bookings/RefundPayment | ➕ POST /api/v2/bookings/{id}/refund | RefundPayment |
| GET /api/Bookings/SendPaymentReceipt | ➕ POST /api/v2/bookings/{id}/receipt | SendPaymentReceipt |
| POST /api/bookings/SendQuote | ➕ POST /api/v2/bookings/send-quote | SendQuote |
| GET /api/DriverApp/Arrived | ➕ POST /api/v2/dispatch/arrived | DriverArrived |
| GET /api/CallEvents/CallerLookup | ➕ GET /api/v2/call-events/caller-lookup | CallerLookup |
| POST /api/SmsQue/SendText | ➕ POST /api/v2/messaging/sms | SendTextMessage |
| GET /api/AdminUI/SendMessageToDriver | ✔ POST /api/v2/messaging/driver | SendMessageToDriver |
| GET /api/AdminUI/SendMessageToAllDrivers | ✔ POST /api/v2/messaging/broadcast | SendMessageToAllDrivers |
| GET /api/AdminUI/DriversOnShift | ✔ GET /api/v2/drivers/on-shift | GetDriversOnShift |
| GET /api/UserProfile/ListUsers | ✔ GET /api/v2/users/list | ListUsers (v1 controller's 30-min memory cache not replicated — server-side perf only) |
| GET /api/UserProfile/GetUser | ➕ GET /api/v2/users/by-username | GetUser |
| POST /api/UserProfile/GetAvailability | ➕ POST /api/v2/users/availability | GetUserAvailability |
| GET /api/UserProfile/GetAllGPS | ✔ GET /api/v2/drivers/gps | GetAllUsersGPS |
| GET /api/Availability/General | ✔ GET /api/v2/availability/general/{date} | GetGeneralAvailability |
| POST /api/LocalPOI/GetPOI | ➕ POST /api/v2/pois/search | GetLocalPOI |
| GET /api/Address/DispatchSearch | ➕ GET /api/v2/address/dispatch-search | DispatchSearch |
| GET /api/Address/Resolve | ➕ GET /api/v2/address/dispatch-resolve | ResolveAddress |
| GET /api/Address/PostcodeLookup | ➕ GET /api/v2/address/postcode-lookup | PostcodeLookup |
| GET /api/Accounts/GetList | ✔ GET /api/v2/accounts | GetAllAccounts |

External calls (getAddress.io, Revolut payment service, Pusher, Google Maps) are unchanged.

### Envelope adapter contract (frontend)

```
v2 success  → { ...data, status: 'success' }          (arrays spread to indexed keys, as v1 did)
v2 4xx      → { ...errorResponse, status: 'fail', message: 'Failed while fetching the data' }
v2 5xx      → { ...errorResponse, status: 'error', message: 'server error while fetching the data' }
```

This exactly reproduces the v1 `handleGetReq`/`handlePostReq` behaviour, so consuming code
(redux thunks, components) is untouched.

## Testing

- **Backend:** `DispatchV2SnapshotTests.cs` — snapshot tests for the new v2 read endpoints +
  error-case tests for mutating endpoints (same Verify + WebApplicationFactory style).
- **Frontend (vitest + RTL):**
  - `apiReq.test.js` — every function: URL, method, payload, envelope unwrapping, error mapping.
  - `eventVisuals.test.js` — all branches of the ported item-styling logic.
  - `layout.test.js` — overlap column assignment, time→pixel math.
  - `DayView.test.jsx` / `AgendaView.test.jsx` / `DispatchScheduler.test.jsx` — render events,
    cell click emits timestamp, event click emits booking, date navigation, merge-mode drag.

## Out of scope

- Any change to `headless-dispatch` (v1 UI) or any v1 route.
- Visual redesign — the v2 app looks the same; only the scheduler engine is in-house.
- Deployment wiring (Vercel project creation) — `vercel.json` is included, project creation is a follow-up.
