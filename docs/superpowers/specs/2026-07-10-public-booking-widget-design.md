# Public Booking Widget — Design Spec

**Date:** 2026-07-10
**Status:** Approved (Peter, 2026-07-10)
**Goal:** A fully working, embeddable, themeable booking widget usable by any Red Taxi tenant website, with the first implementation on the First Taxis site. Staging is the dev environment; First Taxis is the demo client.

## 1. Context and constraints

- The First Taxis site (Vite/React SPA, Vercel) has a decorative quote form: `src/components/forms/QuoteForm.tsx` redirects to `/book-online`, whose form ends in an `alert()`. Nothing calls any API.
- The Red Taxi API's v1 anonymous endpoints (`/api/Bookings/GetPrice`, `/api/WeBooking/CreateCashBooking`, `/api/Address/*`) are **being retired — the widget must not use them**. Equivalent v2 endpoints must be built following the established v2 patterns.
- The existing v2 surface has **no anonymous endpoints**: `PricingController`, `V2/AddressController`, and `CustomerBookingsController` are all `[Authorize]`. The customer app (Flutter, `src/mobile/customer_app`) uses a customer JWT (email+password) — too heavy for a public embed; forcing account creation would kill conversion.
- `TenantResolutionMiddleware` routes anonymous requests to the default tenant (Ace). There is no mechanism for an anonymous caller to identify its tenant. This also affects customer-app anonymous routes (known PRD gap, prd.md §11 "revisit before tenant #2").
- CORS policy `MyPolicy` uses an origin allowlist with `AllowCredentials()` — wildcard impossible; every tenant site would need a config change + redeploy. Unacceptable for a portable widget.
- Staging: API `https://staging-api.redtaxi.co.uk` (runs in Development mode, dev tokens at `GET /dev/token?user=...`), deploy via `staging/rebuild.ps1`, docs in `docs/staging-environment.md`.

## 2. Architecture overview

Three deliverables, shipped in order, each independently verifiable:

1. **Backend (RedTaxi repo, branch `feature/public-booking-widget` off `dev`):** a v2 public API surface (`/api/v2/public/*`) gated by a per-tenant public key, plus tenant-key resolution in middleware, a public CORS policy, and rate limiting. **Zero new business logic** — public endpoints delegate to the same Application-layer handlers the authorized v2 endpoints use.
2. **Widget (RedTaxi repo, `src/frontend/apps/booking-widget`):** a single versioned JS bundle registering a `<redtaxi-booking>` custom element (React inside Shadow DOM), themeable via CSS custom properties, configured via attributes.
3. **First Taxis integration (first-taxis repo, branch `claude/redtaxi-quote-form-api-503eb9`):** mount the widget in the home hero (compact) and `/book-online` (full), themed to the site, events wired to existing GTM helpers.

## 3. Backend design

### 3.1 Tenant public key

- Control DB (`redtaxi_control`): add `public_key` column to `organizations` (format `rtk_pub_<random>`, unique, nullable = tenant not enabled for public booking).
- `TenantResolutionMiddleware`: on requests to `/api/v2/public/*`, read `X-Tenant-Key` header → look up org by `public_key` → build tenant connection string exactly as the JWT branch does (`organization.database_url`).
- **No default-tenant fallback on public routes.** Missing/invalid/unknown key → `401` with the standard v2 error envelope. A misconfigured widget must fail loudly, never book into the wrong company's database.
- Existing behaviour for all other routes is unchanged (JWT claim → org; login paths; default fallback).

### 3.2 New controller: `PublicBookingController` (`api/v2/public`)

Follows existing v2 conventions exactly: `{ success, data, errors[] }` envelope, thin controller → Application `Features/` handlers, DTOs in `RedTaxi.Application/DTOs`, data-annotation validation, same file/naming style as `CustomerBookingsController`.

| Endpoint | Delegates to | Notes |
|---|---|---|
| `POST /api/v2/public/pricing/quote` | existing pricing handler (same as `POST /api/v2/pricing/quote`) | Body `GetPriceRequestDto`; widget always sends `accountNo: 9999` (cash). Response `GetPriceResponseDto`. |
| `GET /api/v2/public/address/search?q=&sessionToken=` | existing v2 address search handler | Autocomplete. |
| `GET /api/v2/public/address/resolve?id=&sessionToken=` | existing v2 address resolve handler | Returns description/postcode/lat/lng. |
| `POST /api/v2/public/bookings/request` | new `Features/PublicBooking/CreatePublicBooking` handler modelled on `CreateCustomerBooking` | Guest variant: no JWT, so passenger identity travels in the payload. Creates the same `WebBooking` record the operator accepts in dispatch. |

**`CreatePublicBookingRequestDto`** (new, in `DTOs/PublicBooking/`): mirrors `CreateCustomerBookingRequestDto` (`Pickup{Description,Postcode,Lat,Lng}`, `Destination{...}`, `Vias[]`, `Passengers`, `ScheduledFor`, `Asap`, `Quote{PriceCash}`) **plus** `PassengerName` (required, max 250), `PhoneNumber` (required, max 20), `Email` (optional, max 250), `Details` (optional, max 2000). `PaymentMethod` fixed to cash server-side. Max lengths match `WebBookingDto` constraints so nothing truncates downstream.

Response: `PublicBookingCreatedDto { RequestId, Status: "requested" }` — same shape as `CustomerBookingCreatedDto`.

### 3.3 CORS and abuse protection

- New named CORS policy `PublicWidget`: `AllowAnyOrigin` (no credentials — these endpoints are anonymous by design), any header, applied **only** to `PublicBookingController` via `[EnableCors("PublicWidget")]`. Tenant routing is handled by the key, not the origin, so new tenant sites need zero API config.
- Per-IP rate limiting on the public endpoints (reuse the existing rate-limiter registration pattern used by the `"auth"` policy): quote/address generous (autocomplete is chatty), booking-create strict.
- The v1 endpoints are untouched; they retire on their own schedule. The widget never references them.

### 3.4 What we deliberately do NOT build now

- Booking status / tracking / cancel for widget bookings (would need a token-per-booking mechanism; phase 2 if wanted — the v2 customer surface already proves the pattern).
- Card payment (no payment endpoints exist anywhere yet; widget is cash-only, like `CreateCashBooking` was).
- Per-tenant origin binding (optional hardening later: bind each key to allowed origins checked in middleware).

## 4. Widget design

### 4.1 Packaging

`src/frontend/apps/booking-widget` — Vite lib-mode build producing one self-contained IIFE bundle (`widget.js`, versioned path `/v1/widget.js`) that registers `<redtaxi-booking>`. React renders inside an open Shadow DOM root so tenant CSS and widget CSS never collide. No externals — tenant sites need exactly one script tag:

```html
<script src="https://<widget-host>/v1/widget.js" defer></script>
<redtaxi-booking
  tenant-key="rtk_pub_xxx"
  api-base="https://staging-api.redtaxi.co.uk"
  phone="01747 000000"
  mode="compact">
</redtaxi-booking>
```

Attributes: `tenant-key` (required), `api-base` (required — staging vs prod), `phone` (required — powers the fallback card), `mode` (`compact` | `full`, default `full`). Attribute changes re-render (observedAttributes).

### 4.2 Flow (state machine)

`journey → quoting → quoted → details → submitting → confirmed`, with `error` reachable from any API-touching state.

1. **journey**: pickup + destination via autocomplete (`/public/address/search`, debounced ≥250ms, one `sessionToken` per lookup session) — selection required because pricing needs postcodes; free text alone cannot be quoted. Date + time (30-min slots, no past times), passengers (1–8), optional vias later (out of scope v1).
2. **quoting**: `POST /public/pricing/quote` with `accountNo: 9999`; show spinner.
3. **quoted**: display `priceDriver` as the fare plus `mileageText` / `durationText`. "Book this taxi" advances; editing journey fields returns to journey and invalidates the quote. A quote older than 15 minutes is re-fetched silently on submit.
4. **details**: name (required), phone (required, UK format validated), email (optional), notes (optional).
5. **submitting**: `POST /public/bookings/request` carrying the quoted price; submit button disabled on first click (double-submit guard).
6. **confirmed**: "Request received — we'll confirm your booking shortly", show reference (`RequestId`), option to book another.
7. **error / degraded**: any network failure, 5xx, or rate-limit response → the form collapses to a **call-us card** using the `phone` attribute, preserving whatever the user typed (state kept; retry button). The widget must never present a dead form or lose input.

### 4.3 Theming

CSS custom properties on the host element, consumed inside the shadow root, all with sane defaults:
`--rt-primary`, `--rt-primary-foreground`, `--rt-surface`, `--rt-text`, `--rt-muted`, `--rt-border`, `--rt-radius`, `--rt-font`. Tenants theme from their own stylesheet (`redtaxi-booking { --rt-primary: #16a34a; }`) without touching the bundle.

### 4.4 Events (analytics hooks)

Composed, bubbling `CustomEvent`s from the host element: `rt:start` (first interaction), `rt:quote` (detail: price, mileage, duration), `rt:booking` (detail: requestId), `rt:error` (detail: stage, message). Tenant sites subscribe with `addEventListener` — the widget itself contains no analytics.

## 5. First Taxis integration (demo client)

- Load the widget script in `index.html`; widget host URL + tenant key via Vite env vars (`VITE_RT_WIDGET_URL`, `VITE_RT_TENANT_KEY`, `VITE_RT_API_BASE` — staging values for now).
- Home hero: `QuoteForm.tsx` becomes a thin wrapper rendering `<redtaxi-booking mode="compact">` with the existing card chrome (header, trust line) kept around it.
- `/book-online`: the fake form is replaced by `<redtaxi-booking mode="full">`; sidebar (phone CTA, trust signals, cancellation policy) stays.
- Theme tokens mapped from the site's existing design system to `--rt-*` variables in `index.css`.
- `rt:start` → `trackQuoteFormStart()`, `rt:booking` → `trackFormSubmit(...)` (existing `src/lib/gtm.ts` helpers).
- Acceptance: a booking submitted on the First Taxis site appears in staging dispatch's web-bookings queue under the First Taxis tenant and can be accepted by an operator.

## 6. Test plan (full, end-to-end, edge-case driven)

### 6.1 Backend (TDD, existing test patterns)

- Tenant-key resolution: valid key → correct tenant connection string; missing key on `/api/v2/public/*` → 401; invalid/unknown key → 401; key never falls back to default tenant; non-public routes unaffected.
- Each public endpoint: happy path; validation failures return envelope errors (bad postcode format, missing required fields, name/details over max length, passengers out of range, past `ScheduledFor`).
- Guest booking handler: creates WebBooking with correct passenger fields, cash scope, quoted price persisted; script/HTML in text fields stored inert (no execution path, encoding preserved).

### 6.2 Contract tests against staging

Scripted real calls (address search → resolve → quote → booking request) asserting live response shapes, so API drift breaks loudly before the widget does.

### 6.3 Widget unit tests (vitest)

API client (envelope unwrapping, error normalization, timeout), state machine transitions (incl. quote invalidation on journey edit, stale-quote refresh, double-submit guard), fallback rendering (API down → call-us card with input preserved).

### 6.4 End-to-end on staging (Playwright)

Full loop: First Taxis page → autocomplete both addresses → live quote renders → guest details → submit → assert confirmation with RequestId → **verify server-side** via `GET /api/v2/web-bookings` (staging dev token) that the booking exists in the First Taxis tenant with the right details and price → accept it in staging dispatch to prove downstream compatibility (allocation path doesn't choke on widget bookings).

### 6.5 Edge cases (tested at API and widget level)

invalid/non-UK postcode; pickup = destination; past pickup date/time; far-future date; 8+ passengers; max-length overflows (address 250, details 2000, postcode 9); special characters + `<script>` in text fields; quote-vs-submit price mismatch; double-click double submission; rate-limit trip (429 → call-us card); API timeout mid-quote and mid-booking (input preserved); dwell >15 min between quote and submit (silent re-quote); wrong tenant key (proves isolation — booking must NOT appear in another tenant); widget on a page with aggressive global CSS (Shadow DOM isolation proof).

## 7. Rollout

1. Backend PR → `dev` (RedTaxi repo, code-reviewer agent first, all issues resolved).
2. Deploy staging (`staging/rebuild.ps1`), seed First Taxis org + `rtk_pub_` key in `redtaxi_control`.
3. Widget bundle hosted (staging URL first; production host `widget.redtaxi.co.uk` when promoted).
4. First Taxis branch → PR, Vercel preview verified against staging, then live.
5. Production cutover later = flip `api-base` + key to prod values; out of scope for this build.

