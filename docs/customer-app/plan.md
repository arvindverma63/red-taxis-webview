# Red Taxi Customer App — Implementation Plan

**Created:** 2026-06-13
**Status:** Approved scope, pre-build
**App:** Ace Taxis customer app (Flutter, iOS + Android) — config-driven for later white-labelling per tenant
**Design base:** [GoRide — Ride-Hailing App UI Kit](https://www.figma.com/community/file/1355586331368945544/goride-ride-hailing-app-ui-kit) ($34, Figma variables, 175+ screens)

---

## 1. Locked decisions

| Decision | Choice |
|---|---|
| Users | Ace Taxis public customers **and** account users, one app |
| Signup | Folded into first booking — reuse booking data (name, email, phone, addresses) |
| Auth v1 | Email/password only (v2 auth endpoints). Social login (Google + Apple) deferred to **v1.1** — note App Store rule 4.8: adding Google login mandates Sign in with Apple |
| Payments | Cash (account 9999) + card/Apple Pay via **Revolut**, **pre-pay at booking**. Account bookings invoice to account (no payment step) |
| Booking workflow | **Operator accepts all** app bookings — they enter the existing WebBooking queue; customer sees "Request sent" then push on accept/reject. Pre-pay + reject ⇒ **auto-refund** via existing `RevoluttService.RefundOrder` |
| Amend/cancel | Reuse webbooking change-request workflow |
| Live tracking | **v1** — driver dot on map; requires new GPS → Pusher publishing (backend) |
| Messaging v1 | None. Status push notifications + "Call office" / "Call driver" buttons |
| Messaging v1.1 | In-app chat to operator, reusing existing WhatsApp conversation infra + operator chat widget in admin-v2 |
| Store accounts | Apple Developer + Google Play accounts already held |

### v1 cut list (explicitly deferred)
Chat, social login, wallet, promos/discounts, tips, ratings, referrals, multi-stop, scheduled-recurring bookings.

### Booking flow TODO
- [ ] Add a structured `luggage` selector to passenger booking details and send it with booking creation payloads, matching the web booker public booking schema.

---

## 2. Design workflow (Figma → Flutter)

Validated 2026 approach: **Figma MCP + Claude Code, tokens-first** — no codegen converters.

1. Buy GoRide, duplicate into RBS Figma account.
2. Rebrand: swap primary color variable green → Red Taxi red (GoRide is variables-driven — near one-change).
3. Mark the v1 screens (page or section) so MCP extraction targets are unambiguous.
4. Connect Figma MCP (remote server `https://mcp.figma.com/mcp`, OAuth, works on free plan; drive by frame URL).
5. Extraction pattern per component/screen: `get_variable_defs` (tokens) + `get_design_context` (structure) + `get_screenshot` (visual ground truth) → build → render → vision-compare → iterate.

### v1 screen list from GoRide (~23 of 175)

| Flow | Screens |
|---|---|
| Onboard/Auth | Splash, onboarding ×2, sign in, sign up, OTP/verify email, forgot password |
| Book | Home (map + "where to?"), address search, pickup/dropoff confirm, vehicle select + fare quote, schedule picker, payment method select, booking confirmation ("request sent") |
| Live | Driver assigned, live tracking map, ride complete/receipt |
| Activity | Current + history list, booking detail (with amend/cancel request) |
| Account | Profile, saved addresses, payment methods, settings, notification inbox |

---

## 3. Flutter stack

| Concern | Choice | Why |
|---|---|---|
| State | Riverpod 3 + riverpod_generator | 2026 consensus for solo + AI-agent builds; low boilerplate, testable |
| Navigation | go_router + go_router_builder | Flutter-docs default; deep links for push-notification taps |
| Maps | google_maps_flutter + geolocator | Backend already uses Google Maps/Places + Ideal Postcodes — one vendor |
| Real-time | pusher_channels_flutter | Backend broadcasts on Pusher; official client |
| Push | firebase_messaging + flutter_local_notifications | FCM infra exists server-side |
| HTTP | dio with QueuedInterceptor | Single-flight refresh matches 15-min access / 30-day rotating refresh model |
| Token storage | flutter_secure_storage | Keychain/Keystore; refresh token only — access token in memory |
| Models | freezed + json_serializable | Standard, agent-friendly |
| Testing | alchemist (golden) + widgetbook (component gallery) | Visual verification loop |
| Payments | Revolut merchant SDK / Revolut Pay (Apple Pay + Google Pay) | Verify Flutter SDK quality in Phase 1; **Stripe is the fallback** if weak |

### Project structure (feature-first)

```
src/mobile/customer_app/
├── lib/
│   ├── main.dart
│   ├── app.dart                  # MaterialApp.router + ThemeData
│   ├── core/
│   │   ├── theme/                # tokens from Figma: colors, text styles, spacing, radius
│   │   ├── widgets/              # design-system component kit
│   │   ├── network/              # dio client + queued-refresh auth interceptor
│   │   ├── realtime/             # pusher service wrapper
│   │   ├── router/               # go_router typed routes
│   │   ├── config/               # tenant/brand config (white-label later)
│   │   └── storage/              # secure storage wrapper
│   └── features/
│       ├── auth/                 # data / domain / application / presentation
│       ├── booking/              # quote → book → confirm
│       ├── tracking/             # live map, driver location
│       ├── activity/             # current + history + detail + amend/cancel
│       ├── payment/
│       ├── profile/              # profile, saved addresses, settings
│       └── notifications/
├── test/
└── CLAUDE.md                     # conventions: theme-only styling, one Notifier per flow, features never cross-import
```

---

## 4. Backend work items (from contract audit, 2026-06-13)

### Exists — reuse as-is
- `POST /api/v2/pricing/quote` — fare quote (acc 9999 = cash), public ✅
- `POST /api/v2/address/search` / `GET resolve` / `GET postcode/{p}` ✅
- v2 auth: login / refresh / forgot / set-password / verify-email ✅
- WebBooking accept/reject/amend + change requests (operator side) ✅
- Revolut: CreateOrder / GetOrderStatus / RefundOrder / payment-link flow ✅
- FCM: Firebase Admin SDK + token storage (driver-shaped) ✅

### To build (phased)

| # | Item | Size | Phase |
|---|---|---|---|
| B1 | Customer self-registration (`POST /api/v2/auth/register-customer`) + "Customer" role + email verify | M | A |
| B2 | v2 create-webbooking endpoint (customer-scoped; mirrors v1 WeBooking create) | M | A |
| B3 | "My bookings" — current + history scoped to authenticated customer/account user | S | A |
| B4 | Customer-scoped amend/cancel change-request endpoints | S | A |
| B5 | Pusher private channels + auth endpoint (`POST /api/v2/pusher/auth`) | S | B |
| B6 | Publish booking status events to Pusher (accepted, allocated, arriving, completed, cancelled) | M | B |
| B7 | Publish driver GPS to booking-scoped private channel (from UpdateUserGPS path) | M | B |
| B8 | FCM triggers on booking events + customer token registration endpoint | M | B |
| B9 | Pre-pay checkout: create Revolut order at booking, link order ↔ webbooking, auto-refund on reject | M | C |
| B10 | Payment status endpoint for app polling/confirmation | S | C |
| B11 | Customer profile + saved addresses CRUD (`/api/v2/customers/me/*`) | M | C |
| B12 | Social login token exchange (Google + Apple → our JWTs) | L | v1.1 |
| B13 | In-app chat to operator via existing WhatsApp conversation infra | L | v1.1 |

All new endpoints follow backend standards: MediatR handler per use case, `Result<T>`, Serilog `Feature` context, routing-only controllers, snapshot tests, tenant scoping via `TenantOrgId` claim.

**Known limit to respect:** booker usernames are account numbers (cross-tenant collision documented in CLAUDE.md) — customer registration must be email-unique per tenant; revisit before tenant #2.

---

## 5. Build phases

**Phase 0 — Setup** (blocks: GoRide purchase)
Buy GoRide → duplicate → red rebrand → mark v1 screens → connect Figma MCP. Scaffold `src/mobile/customer_app` (structure above + CLAUDE.md + CI: `flutter analyze` + `flutter test`). Verify Revolut Flutter SDK; decide Revolut vs Stripe fallback.

**Phase 1 — Tokens + component kit**
`get_variable_defs` → ThemeData (light + dark). Build core widgets (buttons, inputs, cards, bottom sheet, status chips, list tiles) with screenshot vision-verify + goldens.

**Phase 2 — Backend batch A (B1–B4) + app auth feature**
Registration, login, refresh rotation, forgot password, verify email. Signup-within-booking data capture designed here.

**Phase 3 — Booking creation**
Home map → address search (v2 endpoints) → vehicle select → quote (`/pricing/quote`) → schedule picker → payment method select → create webbooking → "request sent" state.

**Phase 4 — Backend batch B (B5–B8) + live features**
Push on accept/reject/allocate. Booking status screen → live tracking map (driver GPS via private channel). Activity list + detail + amend/cancel requests.

**Phase 5 — Backend batch C (B9–B11) + payments + profile**
Pre-pay flow (Apple Pay/card via Revolut), auto-refund on reject. Profile, saved addresses, payment methods, settings, notification inbox.

**Phase 6 — Hardening + release**
Golden tests pass, E2E booking rehearsal against staging, App Store + Play submissions (TestFlight / internal track first). CC/licence attribution n/a (paid licence).

Each phase ends with a previewable milestone (simulator screenshots / screen recording) before the next starts. TDD for non-trivial logic (quote mapping, refresh interceptor, booking state machine).

---

## 6. Risks / watch items

- **Revolut mobile SDK quality for Flutter** — verify early (Phase 0); Stripe fallback decision gate.
- **Pre-pay + operator-reject UX** — refund latency must be communicated in-app ("refund issued, 3–5 days").
- **Driver GPS publishing** — new real-time surface; rate-limit GPS events to avoid Pusher message-count blowup (throttle to e.g. 1 msg/3s per active booking).
- **Pusher 10KB payload limit** — already bitten once (CLAUDE.md); slim payloads on all new events.
- **App bookings out-of-hours** — operator-accept means nobody accepts at 3am; decide auto-accept window or expectation-setting copy.
- **Tenant config in app** — keep brand/tenant in config from day one; hardcoding Ace breaks white-label later.
