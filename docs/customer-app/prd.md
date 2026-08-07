# PRD: Red Taxi Customer App

**Created:** 2026-06-13
**Status:** Approved scope — pre-build
**Owner:** Peter Farrell (Red Banana Studios)
**Companion docs:** [plan.md](plan.md) (build phases + stack), this PRD (what we're building, screen-by-screen + contracts)
**Design base:** [GoRide UI Kit](https://www.figma.com/community/file/1355586331368945544/goride-ride-hailing-app-ui-kit) (purchased)

---

## 1. What we're building

A customer-facing mobile app (Flutter, iOS + Android) for Ace Taxis — the first tenant on the Red Taxi platform. It lets a passenger book a taxi, pay, track the driver live, and manage their bookings and profile. It serves two user types in one app: **public customers** (pay cash or card) and **account users** (bill to a business account). The app is built tenant-config-driven so it can be white-labelled per future tenant without a rewrite.

It is a thin client over the existing Red Taxi .NET API. App bookings enter the **same dispatch workflow** as web bookings — they arrive as *requests* that an operator accepts, at which point they become live dispatch jobs. No parallel booking pipeline is created.

## 2. Goals & non-goals

### Goals (v1)
- A first-time customer can book a taxi end-to-end in under 2 minutes, creating their account *during* the booking (no separate signup wall).
- Quote shown before booking (real fare, from the live pricing engine).
- Card / Apple Pay pre-payment at booking; cash and account bookings need no payment step.
- Live driver-on-map tracking once a driver is allocated.
- Push notification on every booking state change.
- Booking history + amend/cancel requests.
- Account users can bill to their account and book for saved passengers.

### Non-goals (explicitly deferred)
- **Social login** (Google/Apple) → v1.1. v1 is email/password only.
- **In-app chat** → v1.1 (v1 uses call buttons + status pushes).
- Wallet, promos/discounts, tips, ratings, referrals, multi-stop, recurring bookings.
- Driver app changes (separate Flutter app, unaffected).
- Operator-side changes beyond what's needed to surface app bookings (they already see web bookings).

## 3. Personas

| Persona | Books as | Pays | Auth |
|---|---|---|---|
| **Public customer** (one-off or repeat) | Self | Cash or card/Apple Pay (pre-pay) | Email/password, created during first booking |
| **Account user** (business booker) | Self or a saved passenger | Billed to account (no in-app payment) | Existing account credentials (account number or email) — already provisioned via booker invite |

Account 9999 = the system "Cash" account (`SystemAccounts.Cash`). Public-customer cash bookings are scoped to 9999.

## 4. End-to-end flows

### 4.1 First booking (new public customer — the signup-in-booking flow)
1. Open app → onboarding (2 screens) → Home (map, "Where to?").
2. Enter pickup (defaults to current GPS) + destination via address search.
3. Pick vehicle type → **quote** displayed.
4. Pick time (now / schedule later).
5. Pick payment: **Cash** or **Card/Apple Pay**.
6. Tap "Book". If not signed in → inline **"Create account to confirm"** sheet pre-filled with the name/phone/email/addresses already entered. Customer sets a password (or we send a verify-email link). Account created (role `Customer`, scoped to Ace tenant).
7. If card: Revolut/Apple Pay checkout → on success, request submitted. If cash: request submitted immediately.
8. Screen shows **"Request sent — awaiting confirmation"**.
9. Operator accepts in dispatch → push: "Booking confirmed". (Reject → push + **auto-refund** if pre-paid.)
10. Driver allocated → push + live tracking available.

### 4.2 Repeat booking (returning customer)
Signed in (token refreshed silently) → Home → same flow, addresses/payment remembered → Book → request sent. No account step.

### 4.3 Account user booking
Signed in as account → Home → optionally select a **saved passenger** → addresses → vehicle → quote shows account price → time → **"Bill to account"** (no payment step) → request sent.

### 4.4 Amend / cancel
From a current booking → "Request change" or "Cancel" → submits a **web change request** (existing workflow) → operator actions it → push on resolution. Cancel before allocation = clean; after allocation = policy copy ("operator will call you").

## 5. Screen inventory (v1 — ~23 screens from GoRide)

> Each screen lists: purpose, key data, primary actions, the API it calls, and notable states.

### Onboarding / Auth
1. **Splash** — brand load, silent token refresh decision (→ Home if valid, → Onboarding if first run, → Sign in if expired).
2. **Onboarding 1–2** — value props; "Get started" / "Skip".
3. **Sign in** — email/username + password → `POST /api/v2/auth/login`. Link to forgot password.
4. **Sign up** — name, email, phone, password → new `register-customer` (B1). Usually reached *inside* booking, but standalone too.
5. **Verify email** — `POST /api/v2/auth/verify-email` (token from email link / OTP). Non-blocking for v1 booking; required before account marked active.
6. **Forgot password** — `POST /api/v2/auth/forgot-password` → email link → set-password screen (`POST /api/v2/auth/set-password`).

### Booking
7. **Home** — map (current GPS), "Where to?" CTA, saved-address shortcuts, recent destinations, profile/menu entry.
8. **Address search** — `POST /api/v2/address/search` (autocomplete, session token) → `GET /api/v2/address/resolve` (lat/lng). Bias to current location/post town.
9. **Pickup/dropoff confirm** — map with two pins, editable, via-stops (single via supported by pricing; multi-stop deferred).
10. **Vehicle select + quote** — vehicle types; on selection call `POST /api/v2/pricing/quote` (acc 9999 for cash, account no. for account users). Shows price, ETA, distance, duration.
11. **Schedule** — "Now" or date/time picker (themed; future only).
12. **Payment method** — Cash / Card / Apple Pay (public); "Bill to account" (account users). Card → Revolut/Apple Pay sheet.
13. **Booking confirmation** — "Request sent — awaiting confirmation", summary, "Call office".

### Live / status
14. **Status / driver assigned** — state machine: Requested → Confirmed → Driver allocated → Driver arriving → Arrived → In progress → Complete. Subscribes to Pusher private channel (B5/B6).
15. **Live tracking** — map with driver marker moving (driver GPS via Pusher, B7), ETA, driver name/vehicle/plate, "Call driver".
16. **Complete / receipt** — fare breakdown, payment status, "Book again".

### Activity
17. **Activity list** — current (top) + history → `GET /api/v2/customers/me/bookings` (B3). Tabs or sections.
18. **Booking detail** — full booking; for current bookings: "Request change" / "Cancel" (B4 → web change request).

### Account
19. **Profile** — name, email, phone (`GET/PUT /api/v2/customers/me/profile`, B11).
20. **Saved addresses** — CRUD (B11). Home/Work/custom labels.
21. **Payment methods** — manage cards (Revolut tokenisation, B9). Account users: shows account.
22. **Settings** — notifications toggles, theme, sign out, legal links.
23. **Notification inbox** — list of received pushes (booking events), tap → deep link to booking.

## 6. Data model

### Reuse (existing)
- **AppUser** (tenant DB, ASP.NET Identity): `FullName`, `Email`, `UserName`, `PhoneNumber`, roles. New role **`Customer`** for public customers.
- **Account / AccountPassenger** (tenant DB): account users + their saved passengers — unchanged.
- **WebBooking** (tenant DB): the booking *request*. App bookings create these. Fields: `AccNo`, `PickupDateTime`, `PickupAddress/Postcode`, `DestinationAddress/Postcode`, `PassengerName`, `Passengers`, `PhoneNumber`, `Email`, `Status`, `Processed`, optional `Price/Mileage/DurationMinutes` (cash).
- **Booking** (tenant DB): the dispatch job created on accept. Has `Scope` (Account/Cash/Card), `PaymentStatus`, Revolut order id fields.

### New / extended
- **AppUser** gains a customer linkage: app-customer bookings keyed by `Email`/`PhoneNumber` today; **add `CustomerUserId` FK on WebBooking/Booking** for clean "my bookings" scoping (B3 design decision — confirm vs email-match).
- **CustomerSavedAddress** (new, tenant DB): `Id`, `CustomerUserId`, `Label`, `Address1..4`, `Postcode`, `Lat`, `Lng`. (B11)
- **CustomerPaymentMethod** (new or Revolut-token-only): store Revolut customer/token ref, last4, brand — never raw PAN. (B9)
- **FCM token**: stored on `UserProfile.NotificationFCM` (existing) — extend registration path for customers (B8).

## 7. API contract

### Existing — reuse as-is
| Route | Method | Auth | Use |
|---|---|---|---|
| `/api/v2/auth/login` | POST | none | Sign in (username or email + password) |
| `/api/v2/auth/refresh` | POST | none | Token rotation (15-min access / 30-day refresh) |
| `/api/v2/auth/forgot-password` | POST | none | Reset link |
| `/api/v2/auth/set-password` | POST | none | Complete reset / set initial password |
| `/api/v2/auth/verify-email` | POST | none | Confirm email |
| `/api/v2/auth/send-verify-email` | POST | none | Resend verify |
| `/api/v2/pricing/quote` | POST | none | Fare quote (acc 9999 = cash) |
| `/api/v2/address/search` | POST | `[Authorize]` | Autocomplete (session token) |
| `/api/v2/address/resolve` | GET | `[Authorize]` | Resolve to lat/lng |
| `/api/v2/address/postcode/{pc}` | GET | `[Authorize]` | Postcode lookup |
| `/api/WeBooking/CreateWebBooking` | POST | none (v1) | Create account booking request |
| `/api/WeBooking/CreateCashBooking` | POST | none (v1) | Create cash booking request |

> Note: v1 create routes are unauthenticated. For the app we add **authenticated v2 mirrors** so requests are customer-scoped and tenant-resolved from the JWT (B2). Quote stays public.

### New — to build (cross-ref plan.md work items)

| ID | Route | Method | Auth | Returns / does |
|---|---|---|---|---|
| B1 | `/api/v2/auth/register-customer` | POST | none | Create AppUser (role Customer), tenant-scoped, send verify email. Body: name, email, phone, password. Returns login tokens. |
| B2 | `/api/v2/bookings/request` | POST | `[Authorize]` | Customer-scoped create of a WebBooking request (cash or account). Tenant from JWT. Returns requestId + status. |
| B3 | `/api/v2/customers/me/bookings` | GET | `[Authorize]` | Current + past bookings for the caller. Query: `status`, `from`, `to`. |
| B4 | `/api/v2/customers/me/bookings/{id}/change` / `/cancel` | POST | `[Authorize]` | Submit web change/cancel request for own booking. |
| B5 | `/api/v2/pusher/auth` | POST | `[Authorize]` | Sign Pusher private-channel subscription for caller (own booking channel). |
| B8 | `/api/v2/customers/me/fcm-token` | POST | `[Authorize]` | Register device FCM token for the customer. |
| B9 | `/api/v2/bookings/{id}/payment` | POST | `[Authorize]` | Create Revolut order for pre-pay, return checkout/Apple Pay params. |
| B10 | `/api/v2/bookings/{id}/payment-status` | GET | `[Authorize]` | Poll/confirm payment state. |
| B11 | `/api/v2/customers/me/profile` (GET/PUT), `/addresses` (CRUD) | various | `[Authorize]` | Profile + saved addresses. |
| B12 | `/api/v2/auth/social` | POST | none | **v1.1** — exchange Google/Apple token for our JWTs. |

All new endpoints: MediatR handler per use case, `Result<T>`, routing-only controllers, `Log.ForContext("Feature", …)`, snapshot test, tenant-scoped by `tenant_org_id` claim.

## 8. Real-time (Pusher)

- **Today:** one public channel per tenant (`tenant-{orgId}`). No booking-status events, no driver GPS published.
- **v1 adds:**
  - Private per-booking (or per-customer) channel, authed via B5.
  - **Booking status events** (B6): `booking.confirmed`, `booking.allocated`, `booking.arriving`, `booking.arrived`, `booking.in-progress`, `booking.completed`, `booking.cancelled`. Slim payloads (≤10KB — known limit, CLAUDE.md).
  - **Driver GPS** (B7): publish from the existing `UpdateUserGPS` path to the booking's private channel, **throttled** (≤1 msg / 3s per active booking) to avoid Pusher message-count blowup.

## 9. Push notifications (FCM)

- Firebase project + Admin SDK exist (driver app). Add the customer Android + iOS apps → `google-services.json` / `GoogleService-Info.plist`.
- Token registration: B8. Triggers (B8 handlers): fire on each booking status transition → notification + `data` payload carrying `bookingId` for deep-link via go_router.
- Foreground: flutter_local_notifications. Background/terminated: FCM displays, tap routes to booking detail.

## 10. Payments

- **Pre-pay at booking** for card/Apple Pay (decided). Flow: create request → B9 creates Revolut order → Apple Pay / card sheet → on success request is submitted with `Scope=Card`, `PaymentStatus=Pending→Received`.
- **Operator reject after pre-pay → auto-refund** via `RevoluttService.RefundOrder` (B9 handler closes the loop).
- **Cash**: no payment step (`Scope=Cash`, acc 9999).
- **Account**: no payment step (invoiced).
- **SDK risk:** verify Revolut's Flutter/Apple Pay story in Phase 0. **Stripe is the fallback** if weak. (Physical service ⇒ no Apple IAP cut.)
- Revolut secret key not yet configured — Peter to create; gate Phase 5 on it.

## 11. Auth & identity

- Email/password v1. JWT: 15-min access (memory) + 30-day rotating refresh (flutter_secure_storage). dio `QueuedInterceptor` single-flight refresh; on refresh-family revocation → force re-login.
- Tenant resolution unchanged: `tenant_org_id` claim → control DB → tenant connection string.
- **Known limit (CLAUDE.md):** booker usernames are account numbers, which collide across tenants; control-DB login is `username OR email … LIMIT 1`. Customer registration must enforce **email-unique per tenant**; revisit before tenant #2.
- v1.1 social login (B12) ⇒ App Store rule 4.8 mandates Sign in with Apple alongside Google.

## 12. Multi-tenancy / white-label

- App ships with a **tenant/brand config** (org id, brand name, colors, logo, API base URL, support phone) — Ace values at launch, but never hardcoded in widgets. Theme + config are the only things that change to white-label.
- API base, Pusher key/cluster, Maps keys, Firebase config come from build-time `--dart-define` / env per flavor.

## 13. Analytics & monitoring

- **Firebase Analytics** (free, GA4-linked, no new account) — screen views + key funnel events: `booking_started`, `quote_viewed`, `payment_method_selected`, `booking_requested`, `booking_confirmed`, `tracking_opened`.
- **Sentry Flutter** — own project/DSN (create via Sentry MCP). Crash + error reporting, release tracking.

## 14. Error & edge states (must-handle)

- No network / API down → ret[r]y affordance, no data loss on the booking form.
- Quote fails / no price → block booking with clear message, offer "Call office".
- Out-of-hours request (operator-accept model) → set expectation copy ("we'll confirm by phone shortly"); decide auto-accept window later.
- Payment success but request-submit fails → must not double-charge; reconcile via payment-status + auto-refund.
- Token expired mid-session → silent refresh; hard-fail → re-login without losing the in-progress booking.
- Location permission denied → manual pickup entry path.
- Driver GPS stale/absent → fall back to status-stage UI, hide stale marker.

## 15. Acceptance criteria (v1 done)

- [ ] New customer completes first booking incl. account creation in one flow (cash + card paths).
- [ ] Returning customer books in ≤4 taps from Home.
- [ ] Account user can bill to account and book for a saved passenger.
- [ ] Quote shown matches dispatch pricing for the same inputs.
- [ ] Card/Apple Pay pre-pay succeeds; operator reject auto-refunds.
- [ ] Push received on confirm / allocate / arrive / complete / cancel.
- [ ] Live tracking shows driver moving after allocation.
- [ ] Amend + cancel requests reach the operator and resolve with a push.
- [ ] History lists the customer's own bookings only (tenant + user scoped).
- [ ] Runs on iOS (TestFlight) and Android (internal track), both via CI.
- [ ] No tenant hardcoding — config swap only.

## 16. Phased rollout

Mirrors [plan.md](plan.md) §5: Phase 0 setup → Phase 1 tokens+kit → Phase 2 auth (B1–B4) → Phase 3 booking → Phase 4 real-time+tracking (B5–B8) → Phase 5 payments+profile (B9–B11) → Phase 6 hardening+release. Each phase ends with a previewable simulator milestone.

## 17. Open questions

1. **B3 scoping:** add `CustomerUserId` FK (clean) vs match on email/phone (no migration)? → recommend FK.
2. **Out-of-hours bookings:** auto-accept window, or expectation-set copy only? (Operator-accept model means nobody accepts at 3am.)
3. **Cancel-after-allocation policy:** free / charge / operator-call? Needs Ace's real policy.
4. **Apple Pay via Revolut** — confirm merchant account supports it; else Stripe fallback.
5. **Verify-email blocking?** v1 lets unverified customers book (verify async) — confirm acceptable.
6. **iOS CI vs the Mac:** now that a Mac exists — local Xcode builds + SSH, or still Codemagic/GitHub Actions for release signing? (See plan + readiness checklist.)
