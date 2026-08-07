# Red Taxi Booking Widget — Integration Guide

For front-end developers embedding the booking widget on a tenant website (any stack: plain HTML, WordPress, React, Next.js, Vue…). The widget is a self-contained web component: one script, one element, no dependencies, no CSS framework requirements.

Source: `src/frontend/apps/booking-widget` · Public API surface: `/api/v2/public/*` · Reference implementation: the First Taxis site ([firsttaxis repo](https://github.com/redbananastudios/firsttaxis), `src/components/forms/RedTaxiBooking.tsx`).

## 1. Quick start (staging)

```html
<!-- 1. Load the bundle (built from src/frontend/apps/booking-widget: npm run build → dist/v1/widget.js) -->
<script src="/path/to/widget.js" defer></script>

<!-- 2. Mount it -->
<redtaxi-booking
  tenant-key="rtk_pub_..."
  api-base="https://staging-api.redtaxi.co.uk"
  phone="01747 000000"
  mode="full">
</redtaxi-booking>
```

That's the whole integration. The widget handles address autocomplete, live fare quoting, guest details, booking submission and the confirmation screen. Bookings land in the tenant's dispatch web-bookings queue for an operator to accept.

### Attributes

| Attribute | Required | Values | Notes |
|---|---|---|---|
| `tenant-key` | yes | `rtk_pub_…` | Identifies WHICH taxi company the booking belongs to. Issued per tenant (control DB `organization.public_key`). Safe to expose in HTML — it's a public routing key, not a secret. |
| `api-base` | yes | URL | `https://staging-api.redtaxi.co.uk` for testing; production URL at go-live. No trailing slash needed (normalised). |
| `phone` | yes | display string | Powers the fallback "call us" card shown if the API is unreachable or the widget is misconfigured. Never leave visitors with a dead form. |
| `mode` | no | `full` (default) \| `compact` | `compact` is tighter spacing for hero-card embeds. Same flow. |

Missing `tenant-key` or `api-base` → the widget renders the call-us card immediately (fails safe, visibly).

## 2. Getting a tenant key for testing

Keys live in the staging control DB (`organization.public_key`). Ask the platform owner for the tenant you're testing against, or issue one (staging DB access required):

```sql
UPDATE organization
SET public_key = 'rtk_pub_' || encode(gen_random_bytes(24), 'hex')
WHERE id = '<org-id>'
RETURNING public_key;
```

Notes:
- Key changes take up to **60 seconds** to apply (server-side cache TTL). Setting `public_key = NULL` revokes the key (same delay).
- The tenant must have **tariffs configured** in its tenant DB or every quote fails with `QUOTE_FAILED`.
- The First Taxis staging tenant (`org_first_taxis`) is set up and working — good default for widget testing. Its bookings are visible in staging dispatch.

## 3. Theming

All visual styling flows through CSS custom properties set on the element from YOUR stylesheet — you never edit the bundle:

```css
redtaxi-booking {
  --rt-primary: #d61f26;             /* buttons, accents, focus */
  --rt-primary-foreground: #ffffff;  /* text on primary */
  --rt-surface: #ffffff;             /* card/input backgrounds */
  --rt-text: #1a1a1a;                /* body text */
  --rt-muted: #6b7280;               /* secondary text */
  --rt-border: #e5e7eb;              /* input/card borders */
  --rt-radius: 12px;                 /* corner radius */
  --rt-font: inherit;                /* inherit = use your site's font */
}
```

Every property has a sane default; set only what you need. The widget renders in Shadow DOM, so your site's CSS cannot leak in and widget CSS cannot leak out — the `--rt-*` variables are the entire styling contract.

## 4. Analytics events

The element dispatches bubbling, composed `CustomEvent`s — hook your analytics without touching widget code:

| Event | When | `event.detail` |
|---|---|---|
| `rt:start` | First interaction with the form | — |
| `rt:quote` | A fare quote rendered | `{ price, mileage, duration }` |
| `rt:booking` | Booking successfully submitted | `{ requestId }` |
| `rt:error` | An API call failed (widget shows call-us card) | `{ stage, message }` |

```js
document.querySelector("redtaxi-booking")
  .addEventListener("rt:booking", (e) => gtag("event", "booking", { id: e.detail.requestId }));
```

React example (ref + addEventListener in an effect): see `RedTaxiBooking.tsx` in the firsttaxis repo.

## 5. Behaviour you should know before testing

- **Payment**: visitors choose *Cash to the driver*; the *Card* option is intentionally disabled ("coming soon") until the online-payment phase ships. The API already accepts `card` (marks the booking Card-scope for dispatch) — enabling it is the `CARD_ENABLED` flag in `DetailsStep.tsx`.
- **Quotes are server-computed and so is the final price** — the widget-submitted price is ignored server-side (anti-tamper). Quote and booking prices can differ slightly if the visitor dwells >15 min (the widget silently re-quotes on submit).
- **Addresses must come from the autocomplete** (postcode required for pricing). Street-level picks without a postcode prompt the visitor for a more specific address.
- **Rate limits** (per IP): 120/min on quote + address; **10/min on booking creation**. Automated tests that create bookings must pace themselves or expect 429s.
- **Validation** (server, mirrored in the widget): passengers 1–8, pickup not in the past (5-min grace) and ≤90 days out, name ≤250 chars, phone required (UK format in the widget), notes ≤2000.
- **CORS is open** on the public endpoints — you can develop from `localhost` with no API config changes.
- Errors come back in the standard v2 envelope: `{ success, data, errors: [{ code, message }] }`. Codes you'll meet: `TENANT_KEY_REQUIRED`, `TENANT_KEY_INVALID`, `QUOTE_FAILED`, `QUOTE_UNROUTABLE`, `BOOKING_REQUEST_FAILED`.

## 6. Verifying end-to-end

1. Submit a test booking through the widget (name it obviously, e.g. "TEST - do not dispatch").
2. Open staging dispatch → web bookings queue for the tenant — the booking appears with the quoted price and payment scope.
3. Accept or reject it there. Accepting creates a real dispatch job; reject test bookings when done.

Automated references:
- API contract suite: `src/backend/scripts/contract-test-public-api.ps1 -TenantKey rtk_pub_...` (26 checks incl. edge cases).
- Browser e2e: `tests/e2e/booking-widget.spec.ts` in the firsttaxis repo (Playwright, drives the real widget against staging).

## 7. Direct API reference (if you're building a custom UI instead of embedding)

All requests need the `X-Tenant-Key` header. Bodies/responses are camelCase JSON in the v2 envelope.

| Endpoint | Purpose |
|---|---|
| `POST /api/v2/public/pricing/quote` | Fare quote. Body: `{ pickupPostcode, destinationPostcode, viaPostcodes: [], pickupDateTime: "YYYY-MM-DDTHH:mm:00", passengers, priceFromBase: false, accountNo: 9999 }` → `{ priceDriver, mileageText, durationText }`. Datetimes are UK wall-clock. |
| `POST /api/v2/public/address/search` | Autocomplete. Body: `{ query, sessionToken, limit }` → `{ suggestions: [{ id, label, … }], sessionToken }`. One UUID sessionToken per lookup session. |
| `GET /api/v2/public/address/resolve?id=&sessionToken=` | Resolve a suggestion → `{ formattedAddress, postcode (nullable!), lat, lng, … }`. |
| `POST /api/v2/public/bookings/request` | Create guest booking. Body: `{ pickup: { description, postcode, lat, lng }, destination: {…}, vias: [], passengers, scheduledFor, asap, passengerName, phoneNumber, email, details, paymentMethod: "cash"\|"card", quote: { priceCash } }` → `{ requestId, status: "pending" }`. |

Widget source (`src/api.ts`) is the canonical client implementation.
