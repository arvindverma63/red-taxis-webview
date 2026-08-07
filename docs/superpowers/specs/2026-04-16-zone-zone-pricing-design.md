# Zone-to-Zone Pricing — Design Spec

**Date:** 2026-04-16
**Branch:** `feature/zone-zone-pricing`
**Status:** Design approved, implementation plan pending
**Scope:** PR1 = admin CRUD + standalone quote endpoint. PR2 = dispatch + AI agent integration.

---

## 1. Problem

Red Taxi currently prices every booking via mileage × tariff. Some routes — airport runs, seaport transfers, long-distance drops — have a conventional flat fare that operators agree with customers regardless of actual mileage variance. Operators want to define named geographic zones (polygons), pair them in a matrix, and enter a binding flat fare per pair. When both pickup and drop fall inside a defined pair, the zone price wins; otherwise the existing mileage engine runs unchanged.

Target end state: zone pricing applies transparently across every booking channel — dispatch booking form, WhatsApp AI agent quotes, voice AI agent quotes, web booking quote — with no change in caller code beyond a small price-source indicator ("ZONE £225" vs "MILEAGE £47").

Phase 1 scope: **CASH account (9999)** bookings only, with the data model designed to support per-account overrides from day one (via `AccountNumbers int[]` column).

---

## 2. Decisions reached during brainstorming

| # | Decision | Locked |
|---|---|---|
| Tariff 1/2/3 model | Single T1 base cost/price per pair. T2/T3 derived via global tenant multipliers (default T2=1.25, T3=1.50). No per-pair overrides. | ✓ |
| Fallback trigger | Both pickup AND drop must be in defined zones AND matrix row must exist. Otherwise fall through to existing mileage engine. | ✓ |
| Overlapping zones | Disallowed. Server rejects overlap at save time. Drawing UI snaps to existing zone edges for seamless shared borders. | ✓ |
| Coordinates source | Read from stored `Booking.PickupLat/Lng` + `Booking.DestinationLat/Lng` (new columns). Pre-backfill fallback: on-demand Google/Ideal geocoding cached to `PostcodeCoordinates` tenant table. | ✓ |
| Same-zone trips | No matrix row allowed (diagonal blocked by check constraint). Same-zone booking → falls through to mileage. | ✓ |
| MPV surcharge | Still applies on top of zone price (tenant's `LargeVehicleSurchargePercent`, default 50%). Applied to both cost and price. | ✓ |
| Minimum fare floor | Does **not** apply to zone-priced bookings. Matrix number is authoritative. | ✓ |
| Via pricing | Compare (pickup → vias → drop) miles vs direct miles: if extra ≤ threshold (default 2 mi), add flat stop fee per via; else add extra miles × detour rate. Applied to both cost and price. | ✓ |
| Account scoping | `AccountNumbers int[]` column on matrix. `NULL` = default row. `[9999]` = cash-only. `[9014]` = per-account override. Resolver picks most-specific match first, falls back to default, falls back to mileage. | ✓ |
| Integration style | Middleware override — inject `IZonePricingResolver` into existing handlers (`CreateBooking`, `GetCashPrice`, `GetDuration`, AI tool endpoints). If resolver returns a price, use it; else continue to existing tariff math. | ✓ |
| Phasing | Two PRs. PR1 = migrations + CRUD + admin UI + standalone quote endpoint. PR2 = wire resolver into all booking-creation and AI-agent paths. | ✓ |
| Geometry library | `NetTopologySuite` NuGet. Handles self-intersection, polygon overlap, point-in-polygon, centroid, area. | ✓ |
| Admin permissions | Admin role only — same as other `/settings/*` pages. | ✓ |
| Admin page structure | Two pages: `/settings/zone-pricing/zones` (map editor) + `/settings/zone-pricing/matrix` (pricing grid + multipliers/fees side card). | ✓ |
| Matrix CSV import/export | Ship in PR1. | ✓ |
| Pre-backfill behaviour | Enable the feature immediately. Geocode-to-`PostcodeCoordinates`-cache on first lookup. Once operator-supplied lat/lng backfill arrives, cache is bypassed where `Booking.PickupLat` is populated. | ✓ |
| QA approach | Backend snapshot tests (Verify) + staging browser QA via Chrome DevTools MCP + scripted curl walk of the quote endpoint + screenshot handoff to user. | ✓ |
| Preserved v1 | `GeoFences` + `ZoneToZonePrices` tables stay in schema; `WeBookingController` polygon endpoints and `AccountsController.AddOrUpdateZonePrice` remain functional. Zero v1 contract change. | ✓ |

---

## 3. Data model

All new tables in **tenant DB** (per-tenant isolation by construction — the existing SaaS architecture). Migrations added as a single EF Core migration `AddZonePricingTables`.

### 3.1 `ZonePolygons`

| Column | Type | Notes |
|---|---|---|
| `Id` | `int` PK | |
| `Name` | `varchar(100)` NOT NULL | e.g. "Heathrow Airport", "Gillingham" |
| `Points` | `jsonb` NOT NULL | Array of `{lat, lng}` — open polygon (last ≠ first; closed on read) |
| `CentroidLat` | `numeric(9,7)` NOT NULL | Computed server-side on save via NetTopologySuite |
| `CentroidLng` | `numeric(10,7)` NOT NULL | ″ |
| `AreaKm2` | `numeric(10,4)` NOT NULL | Computed ″ |
| `BoundingMinLat` | `numeric(9,7)` NOT NULL | For O(1) reject in resolver |
| `BoundingMaxLat` | `numeric(9,7)` NOT NULL | ″ |
| `BoundingMinLng` | `numeric(10,7)` NOT NULL | ″ |
| `BoundingMaxLng` | `numeric(10,7)` NOT NULL | ″ |
| `IsActive` | `boolean` NOT NULL default `true` | Soft-toggle/delete |
| `CreatedAt` | `timestamptz` NOT NULL default `now()` | |
| `UpdatedAt` | `timestamptz` NOT NULL default `now()` | |

**Indexes:** `(IsActive)`, `(Name)` unique partial where `IsActive`, `(BoundingMinLat, BoundingMaxLat, BoundingMinLng, BoundingMaxLng)` for bbox filter.

### 3.2 `ZonePriceMatrix`

| Column | Type | Notes |
|---|---|---|
| `Id` | `int` PK | |
| `FromZoneId` | `int` FK → `ZonePolygons.Id` NOT NULL | |
| `ToZoneId` | `int` FK → `ZonePolygons.Id` NOT NULL | |
| `AccountNumbers` | `int[]` NULL | `NULL` = default. `[9999]` = cash-only. `[9014, 9022]` = specific accounts. |
| `Tariff1Cost` | `numeric(10,2)` NOT NULL | Driver cost for T1 |
| `Tariff1Price` | `numeric(10,2)` NOT NULL | Customer price for T1 |
| `IsActive` | `boolean` NOT NULL default `true` | |
| `CreatedAt` | `timestamptz` NOT NULL default `now()` | |
| `UpdatedAt` | `timestamptz` NOT NULL default `now()` | |

**Constraints:**
- `CHECK (FromZoneId <> ToZoneId)` — diagonal disallowed.
- Partial unique index on `(FromZoneId, ToZoneId) WHERE AccountNumbers IS NULL AND IsActive` — only one "default" row per pair.
- Soft-rule enforced at UI + handler: warn if same account number appears in two rows for same pair.

**Indexes:** `(FromZoneId, ToZoneId, IsActive)`, GIN on `AccountNumbers` for array-containment queries.

### 3.3 `PostcodeCoordinates` (cache)

Pre-backfill fallback. Once populated, geocoding API stays idle.

| Column | Type | Notes |
|---|---|---|
| `Id` | `int` PK | |
| `Postcode` | `varchar(10)` NOT NULL | Normalised uppercase, no spaces |
| `Latitude` | `numeric(9,7)` NOT NULL | |
| `Longitude` | `numeric(10,7)` NOT NULL | |
| `Source` | `varchar(20)` NOT NULL | `'google'`, `'ideal'`, `'manual'`, `'booking'` |
| `CachedAt` | `timestamptz` NOT NULL default `now()` | |

**Indexes:** `(Postcode)` unique.

### 3.4 `Booking` — new columns (prerequisite follow-up)

These columns are required by the resolver but capture is a separate workstream (operator backfill data + address picker integration). Migration ships with the columns nullable so existing bookings are unaffected.

| Column | Type |
|---|---|
| `PickupLat` | `numeric(9,7)` NULL |
| `PickupLng` | `numeric(10,7)` NULL |
| `DestinationLat` | `numeric(9,7)` NULL |
| `DestinationLng` | `numeric(10,7)` NULL |

**Note:** New bookings should be captured with lat/lng populated from the address picker. Existing bookings are backfilled from operator-provided dataset (post-PR1). Resolver uses `PostcodeCoordinates` fallback whenever these are null.

### 3.5 Tenant settings (stored in existing `TenantSettings` key/value table)

| Key | Type | Default | Notes |
|---|---|---|---|
| `ZonePricing.Enabled` | bool | `false` | Master toggle. When `false`, resolver always returns null. |
| `ZonePricing.Tariff2Multiplier` | decimal | `1.25` | T2 uplift |
| `ZonePricing.Tariff3Multiplier` | decimal | `1.50` | T3 uplift |
| `ZonePricing.StopFee` | decimal | `5.00` | £ per on-route via |
| `ZonePricing.DetourThresholdMiles` | decimal | `2` | Extra miles threshold above which detour billing applies |
| `ZonePricing.DetourPerMileRate` | decimal | `null` | £/mile for detour. If null, fall back to T1's `AdditionalMileCharge`. |

### 3.6 Preserved v1 tables

`GeoFences` and `ZoneToZonePrices` remain in schema — no columns altered, no data touched. The v1 endpoints using them continue to work:
- `POST /api/WeBooking/CreatePolygon` + `UpdatePolygon`
- `POST /api/Accounts/AddOrUpdateZonePrice`

V2 code does not read/write those tables. Future cleanup deferred.

---

## 4. Pricing engine

### 4.1 Interface

```csharp
// RedTaxi.Application.Features.ZonePricing
public interface IZonePricingResolver
{
    Task<ZonePricingResult?> TryResolveAsync(ZonePricingQuery q, CancellationToken ct);
}

public record ZonePricingQuery(
    double? PickupLat, double? PickupLng,
    double? DropLat,   double? DropLng,
    string? PickupPostcode,
    string? DestinationPostcode,
    int AccountNo,
    DateTime PickupDateTime,
    bool IsLargeVehicle,
    IReadOnlyList<ViaPoint>? Vias);

public record ViaPoint(double? Lat, double? Lng, string? Postcode);

public record ZonePricingResult(
    decimal Cost,
    decimal Price,
    int FromZoneId, string FromZoneName,
    int ToZoneId,   string ToZoneName,
    TariffType Tariff,
    string Reason);   // "zone-matrix" | "zone+stop-fee" | "zone+detour"
```

Returns `null` if:
- Master toggle `ZonePricing.Enabled` is false
- Either endpoint's lat/lng cannot be resolved (null after postcode cache lookup + geocoding)
- Either endpoint is not inside any active zone
- No matrix row exists for the (FromZone, ToZone, AccountNo) tuple
- Any internal error occurs (logged + silently falls back to mileage — bookings never blocked by zone code)

### 4.2 Zone lookup — two-phase point-in-polygon

**Phase 1:** In-memory `List<ZonePolygon>` per tenant connection string, loaded lazily on first resolver call for that tenant (not at startup — startup would require knowing every active tenant upfront). Subsequent calls use the cache. Invalidated on zone CRUD via in-process event. Bounding-box pre-filter rejects most polygons in O(1).

**Phase 2:** `NetTopologySuite.Geometries.Polygon.Contains(Point)` on surviving candidates. O(vertex count).

Since overlaps are forbidden at save time, first match wins. No runtime tiebreak.

**Cache invalidation:** `ZoneCacheInvalidator` singleton per tenant connection string, exposing `Invalidate()` called from `CreateZone`, `UpdateZone`, `DeleteZone` handlers.

### 4.3 Coordinate resolution order

```
1. Use query.PickupLat/Lng if both non-null.
2. Else look up PickupPostcode in PostcodeCoordinates cache.
3. Else geocode (tenant's AddressProvider: Google or Ideal) + insert into cache.
4. Else return null (cannot resolve → resolver returns null → mileage fallback).
```

Same flow for drop + each via. Geocoding is fire-and-forget for cache warmup but blocking for the current quote.

### 4.4 Matrix lookup

```csharp
// Try most-specific first
var row = await _db.ZonePriceMatrix
    .Where(r => r.FromZoneId == fromId && r.ToZoneId == toId && r.IsActive
        && r.AccountNumbers != null
        && r.AccountNumbers.Contains(accountNo))
    .FirstOrDefaultAsync(ct);

// Fall back to default (NULL AccountNumbers)
row ??= await _db.ZonePriceMatrix
    .Where(r => r.FromZoneId == fromId && r.ToZoneId == toId && r.IsActive
        && r.AccountNumbers == null)
    .FirstOrDefaultAsync(ct);

if (row == null) return null;
```

### 4.5 Tariff + multiplier

```csharp
var tariff = _tariffSelector.GetTariff(q.PickupDateTime);  // existing
var (t2, t3) = await GetMultipliersAsync();  // tenant settings

var mult = tariff.Type switch {
    TariffType.Tariff_1 => 1.0m,
    TariffType.Tariff_2 => t2,
    TariffType.Tariff_3 => t3,
    _ => 1.0m
};

decimal cost  = Math.Round(row.Tariff1Cost  * mult, 2, MidpointRounding.AwayFromZero);
decimal price = Math.Round(row.Tariff1Price * mult, 2, MidpointRounding.AwayFromZero);
```

### 4.6 Large-vehicle surcharge

```csharp
if (q.IsLargeVehicle) {
    var pct = await _tenantConfig.GetDecimalAsync("LargeVehicleSurchargePercent", 50m);
    cost  = Math.Round(cost  * (1 + pct / 100m), 2);
    price = Math.Round(price * (1 + pct / 100m), 2);
}
```

### 4.7 Via pricing

```csharp
if (q.Vias?.Count > 0) {
    var directMiles = await _distance.GetDrivingDistanceAsync(pickup, drop, ct);
    var viaMiles    = await _distance.GetDrivingDistanceViasAsync(pickup, q.Vias, drop, ct);
    var extra = viaMiles - directMiles;

    if (extra <= thresholdMiles) {
        // On-route via(s): flat stop fee per via.
        var fee = stopFee * q.Vias.Count;
        cost  += fee;
        price += fee;
        reason = "zone+stop-fee";
    } else {
        // Diversion: charge mileage on extra miles. Stop fee does NOT stack
        // on top — detour billing is considered inclusive of the stop itself.
        var rate = detourPerMile ?? tariff.AdditionalMileCharge;
        var add  = (decimal)extra * rate;
        cost  += Math.Round(add, 2);
        price += Math.Round(add, 2);
        reason = "zone+detour";
    }
}
```

### 4.8 Performance target

- Zone resolution + matrix lookup < 5 ms for tenants with ≤ 100 zones, ≤ 10k matrix rows.
- Zero Google calls when lat/lng already known (common case once backfill lands).
- One Google call per quote if postcode geocoding cache miss.
- One additional Google call if vias present (for via-route mileage).

### 4.9 DI registration

```csharp
services.AddScoped<IZonePricingResolver, ZonePricingResolver>();
services.AddSingleton<ZoneCacheInvalidator>();
services.AddScoped<IZoneGeometryService, ZoneGeometryService>();  // wraps NetTopologySuite
services.AddScoped<IPostcodeGeocoder, PostcodeGeocoder>();
```

---

## 5. API endpoints

All v2, under `/api/v2/zone-pricing/*`. All responses use the v2 envelope (`{success, data, errors}`). Handlers return `Result<T>` → `ToActionResult()`.

### 5.1 Zones CRUD

| Method | Route | Handler | Auth | Description |
|---|---|---|---|---|
| GET | `/api/v2/zone-pricing/zones` | `ListZones` | Admin | All zones + points |
| GET | `/api/v2/zone-pricing/zones/{id}` | `GetZone` | Admin | Single zone |
| POST | `/api/v2/zone-pricing/zones` | `CreateZone` | Admin | Create (validates geometry + overlap) |
| PUT | `/api/v2/zone-pricing/zones/{id}` | `UpdateZone` | Admin | Update (revalidates) |
| DELETE | `/api/v2/zone-pricing/zones/{id}` | `DeleteZone` | Admin | Soft-delete. Blocks if active matrix rows reference it. |
| POST | `/api/v2/zone-pricing/zones/validate` | `ValidateZone` | Admin | No DB write. Returns `{valid, issues[]}`. |

### 5.2 Matrix

| Method | Route | Handler | Auth | Description |
|---|---|---|---|---|
| GET | `/api/v2/zone-pricing/matrix?accountNo=9999` | `ListMatrix` | Admin | Zones + cells. Optional filter. |
| PUT | `/api/v2/zone-pricing/matrix` | `UpsertMatrix` | Admin | Batch upsert (merge). Rows in the request are inserted or updated in a single transaction. Rows NOT in the request are **preserved** — removal requires explicit `DELETE`. |
| DELETE | `/api/v2/zone-pricing/matrix/{id}` | `DeleteMatrixRow` | Admin | Soft-delete. |
| GET | `/api/v2/zone-pricing/matrix/export?accountNo=9999` | `ExportMatrix` | Admin | CSV download. |
| POST | `/api/v2/zone-pricing/matrix/import` | `ImportMatrix` | Admin | CSV upload. Returns `{inserted, updated, errors[]}`. |

### 5.3 Quote

| Method | Route | Handler | Auth | Description |
|---|---|---|---|---|
| POST | `/api/v2/zone-pricing/quote` | `GetZoneQuote` | Operator+ | Standalone quote. Used by admin "Test" tool, dispatch form preview, smoke tests. |

Request:
```json
{
  "pickupLat": 51.005, "pickupLng": -2.272,
  "dropLat": 51.470, "dropLng": -0.454,
  "pickupPostcode": "SP8 4QA", "destinationPostcode": "TW6 3XA",
  "accountNo": 9999,
  "pickupDateTime": "2026-04-20T10:00:00Z",
  "isLargeVehicle": false,
  "vias": []
}
```

Response:
```json
{
  "success": true,
  "data": {
    "matched": true,
    "cost": 195.00, "price": 225.00,
    "fromZone": { "id": 1, "name": "Gillingham" },
    "toZone":   { "id": 2, "name": "Heathrow Airport" },
    "tariff": "Tariff_1",
    "reason": "zone-matrix"
  }
}
```

Unmatched:
```json
{ "success": true, "data": { "matched": false, "fallbackToMileage": true } }
```

### 5.4 Settings surfaced via existing `/api/v2/settings/*`

Admin UI reads/writes `ZonePricing.*` keys via existing settings endpoints. No new route required.

### 5.5 Snapshot test coverage (ships in PR1)

- `GET zones` empty tenant
- `POST zones` valid, invalid (too few points, self-intersecting, overlapping, duplicate name)
- `POST zones/validate` all above cases without DB write
- `POST matrix` valid, conflicting default, diagonal rejection
- `POST matrix/import` valid CSV, malformed CSV, partial success
- `POST quote` — 6 scenarios:
  1. Both in zones, matrix exists, T1 cash → `cost/price` match
  2. Same as 1 on a Sunday → T2 multiplier applied
  3. Same as 1 on Christmas Eve 19:00 → T3
  4. Pickup outside any zone → `matched:false`
  5. With on-route via → `reason:"zone+stop-fee"`
  6. With diversion via → `reason:"zone+detour"`
- `DELETE zones/{id}` with active matrix rows → 400 with blocking matrix row IDs

---

## 6. Admin UI

Two pages under `Settings → Zone Pricing`. Navigation entry added to `src/lib/navigation.ts`.

### 6.1 `/settings/zone-pricing/zones`

Polygon editor. Full-viewport map.

**Layout:** map (70%) + sidebar list (30%). Sidebar shows zones with coloured chip, area km², vertex count, active toggle, edit button, delete button.

**Map setup:**
- `@vis.gl/react-google-maps` Map with `mapTypeId="roadmap"` and styles loaded from `getMapStyles(tenantMapStyleName)` (existing `src/lib/map-styles.ts`).
- Google Maps Drawing Library (`libraries: ['drawing', 'geometry']`) loaded via `APIProvider`.
- Drawing manager enabled in draw mode, disabled in view/edit mode.

**Drawing assistance (as designed in Section 2 of brainstorming):**
- Snap-to-existing-edge within 12 px (project mouse → nearest edge of nearest active zone via `google.maps.geometry.spherical`; if within threshold, replace click location with projected point).
- Snap-to-existing-vertex within 15 px (stronger snap).
- Snap-to-close (first vertex) within 15 px when ≥ 3 vertices already placed.
- Live self-intersection check (call `POST zones/validate` debounced at 300 ms); offending edge rendered red. Save disabled when invalid.
- Live overlap check (same endpoint); overlap region shaded red. Save disabled.
- Escape cancels drawing. Enter closes polygon.

**Component files:**
- `src/app/(dashboard)/settings/zone-pricing/zones/page.tsx` — shell + layout
- `src/components/admin/zone-editor/ZoneMap.tsx` — map wrapper + drawing manager
- `src/components/admin/zone-editor/ZoneSidebar.tsx` — list of zones + actions
- `src/components/admin/zone-editor/ZoneSaveDialog.tsx` — Name + Save confirmation
- `src/components/admin/zone-editor/snap-helpers.ts` — pure snap math
- `src/lib/hooks/use-zones.ts` — TanStack Query wrapper

### 6.2 `/settings/zone-pricing/matrix`

Price matrix editor + settings side card.

**Layout:** two-column. Main (75%) = matrix grid. Side card (25%) = multipliers + fees form.

**Matrix grid:**
- Rows = zones (From). Columns = zones (To). Cell contains Cost + Price inputs (both editable).
- Diagonal cells disabled (shaded, no inputs).
- Inputs hide browser spinners (`type="text" inputMode="numeric" pattern="[0-9]*\\.?[0-9]*"`).
- "Save All Changes" button top-right. Calls `PUT /matrix` with all changed rows.
- Account scope selector at top: `All (default)` | `Cash (9999)` | `Account: [typeahead]` — filters which AccountNumbers scope the grid represents. PR1 defaults to `Cash (9999)`; `All` and per-account require toggling Phase 2 UI flag (not exposed in PR1).

**Side card:**
- `ZonePricing.Enabled` toggle
- `Tariff2Multiplier` / `Tariff3Multiplier` number inputs (step 0.01)
- `StopFee` currency input
- `DetourThresholdMiles` number input
- `DetourPerMileRate` number input (blank = inherit T1 per-mile)
- Save button — calls existing `/api/v2/settings/*` bulk update

**CSV import/export:**
- Export button → GET `/matrix/export?accountNo=X` → download
- Import button → file picker → POST `/matrix/import` → toast with `{inserted, updated, errors}` summary, with error rows shown in a modal if any

**Component files:**
- `src/app/(dashboard)/settings/zone-pricing/matrix/page.tsx`
- `src/components/admin/zone-editor/MatrixGrid.tsx`
- `src/components/admin/zone-editor/PricingSettingsCard.tsx`
- `src/components/admin/zone-editor/MatrixCsvImportDialog.tsx`
- `src/lib/hooks/use-zone-matrix.ts`

### 6.3 Price-source indicator (booking form chip)

In `headless-dispatch` (`src/frontend/apps/headless-dispatch/src/components/BookingForm/QuoteDialog.jsx` + wherever price renders inline on the booking form):

- When quote response includes `zone` info → render chip `ZONE · Gill → LHR · £225` next to the price.
- When zone didn't match → render chip `MILEAGE · £47`.
- When vias add detour/stop → append `+£5 stop` or `+£X detour`.

Chip component: `PriceSourceChip` in admin-v2 shared UI, re-exportable to headless-dispatch. Keeps look consistent across apps.

---

## 7. Integration (PR2 scope)

Zone resolver injected into every handler that quotes cash prices. Additive — if resolver returns null, existing mileage path runs unchanged.

### 7.1 Touched handlers

| Handler | Location | Change |
|---|---|---|
| `CreateBooking.Handler` | `Features/Bookings/CreateBooking.cs` | Before `TariffService.Get9999CashPrice`, call `_zoneResolver.TryResolveAsync`. If hit, populate `Booking.Price`, `Booking.Mileage` (zone-priced bookings get a synthetic `Mileage = directMiles` for reporting), and tag `Booking.PriceSource = "zone"`. |
| `GetCashPrice.Query.Handler` | `Features/Pricing/GetCashPrice.cs` | Same pattern. Resolver first, fall through to existing tariff calc. Response shape extended with `fromZone`, `toZone`, `reason`. |
| `GetDuration.Handler` | `Features/WebBookings/GetDuration.cs` | Same. |
| WhatsApp AI quote (`WhatsAppAgentOrchestrator`) | `RedTaxi.AI/WhatsApp/` | Existing `GetCashPrice` MediatR query already covers this — resolver runs transparently. No tool-level change. |
| Voice AI quote (`AiAgentController.QuoteTool`) | `RedTaxi.AI/Controllers/` | Same. |
| Intelligence fast-path (`IntelligenceCache.LookupRoute`) | `RedTaxi.AI/Intelligence/` | Wrap existing return value — if zone-priced, return the zone price; else existing cached route. |

### 7.2 New `Booking` column

`PriceSource` (`varchar(10)` NOT NULL default `'mileage'`) — values: `'mileage'`, `'zone'`. Enables reporting + clear audit.

### 7.3 Metering/logging

- Resolver success → `Log.Information("ZonePricing_Resolved {FromZone}→{ToZone} Tariff={Tariff} Reason={Reason} Price={Price}")`
- Resolver null (expected) → Debug level, not Information (silent fallback)
- Resolver error → `Log.Error(ex, "ZonePricing_Failed — falling back to mileage")` + return null
- `UserActionsLog` entry on every zone save / matrix upsert / import with operator username

---

## 8. Data migration + follow-ups

### 8.1 Migration ships in PR1

Single EF Core migration `20260416_AddZonePricingTables`:
1. `ZonePolygons`, `ZonePriceMatrix`, `PostcodeCoordinates` tables
2. `Booking.PickupLat`, `PickupLng`, `DestinationLat`, `DestinationLng`, `PriceSource` columns (all nullable / defaulted)
3. Postgres `int[]` support via Npgsql — already enabled in `RedTaxiDbContext`
4. No data seeding — tenants enable + populate via admin UI

### 8.2 Follow-ups (post-PR2, separate PRs)

1. **Lat/lng backfill** — user provides dataset keyed on booking ID or postcode. Admin one-off script `Tools/BackfillBookingCoordinates.cs`. Writes `PickupLat/Lng` + `DestinationLat/Lng`. After run, `PostcodeCoordinates` cache becomes a fallback-only path for edge cases.
2. **Address picker lat/lng capture** — update `CreateBooking` and `UpdateBooking` write paths to populate the new coord columns from the address picker's resolved lat/lng. Ensures every new booking after migration has coords captured at source.
3. **Dispatch booking-form price chip** — ship in PR2.
4. **Per-account scope UI** — already supported by backend. UI toggle currently locked to cash-only; PR3 unlocks account picker + reveals matrix rows per account.
5. **MPV separate matrix** — if operators want different Heathrow rates by vehicle type beyond the flat +50%, add `VehicleType` column to `ZonePriceMatrix` and secondary UI.
6. **V1 table cleanup** — once no callers remain, drop `GeoFences` + `ZoneToZonePrices`. Not in this roadmap.

---

## 9. Testing strategy

### 9.1 Backend (PR1)

- 12+ new Verify snapshots covering CRUD + validation + quote scenarios (listed §5.5).
- Unit tests for `ZoneGeometryService`: point-in-polygon with simple + concave polygons, edge cases (point exactly on edge — treat as inside), overlap detection, self-intersection detection.
- Unit tests for `ZonePricingResolver`: all 6 quote scenarios + two failure modes (no zones, resolver throws).
- `WebApplicationFactory` integration tests for every endpoint.

### 9.2 Backend (PR2)

- Existing `CreateBooking` snapshots — add 2 that exercise zone-priced paths.
- `GetCashPrice` snapshots — add 2 (matched zone / fallback).
- WhatsApp agent — one new test using mocked AI tool call that hits a zone.

### 9.3 Frontend

- Manual QA via Chrome DevTools MCP:
  - Load `/settings/zone-pricing/zones` → draw a polygon → save → verify persistence.
  - Draw overlapping polygon → verify save blocked.
  - Open `/settings/zone-pricing/matrix` → enter prices → save → verify persistence.
  - CSV export/import round-trip.
  - Screenshot each step for user handoff.
- Visual regression against map style (light/dark/retro/aubergine) — screenshot in each.

### 9.4 End-to-end smoke (PR2)

Scripted curl walk:
```bash
1. POST zones — create "Gillingham" + "Heathrow Airport"
2. POST matrix — 2 rows (both directions) @ £195/225 and £200/235
3. POST quote — Gillingham→Heathrow coords → expect match + £225
4. POST quote — arbitrary coords outside → expect matched:false
5. POST quote — with via in middle → expect zone+stop-fee
6. POST /api/v2/bookings — zone-priced booking via CreateBooking → verify Booking.PriceSource="zone"
```

---

## 10. Operational considerations

- **Feature flag:** `ZonePricing.Enabled` per-tenant master toggle. Disabled by default. Zero runtime risk to existing tenants.
- **Rollback:** if PR2 causes issues, setting `ZonePricing.Enabled=false` in the tenant's settings instantly reverts all pricing paths to mileage-only. No code redeploy needed.
- **Resolver failure mode:** every exception inside `TryResolveAsync` is caught, logged at Error, and returns `null` — guarantees mileage fallback. Bookings never blocked by zone bug.
- **Performance monitoring:** log resolver duration + hit/miss. Target p95 < 5ms, p99 < 20ms. Alert via Sentry if > 100ms.
- **Staging verification:** every deploy ends with `scripts/verify-staging.ps1` + a quote endpoint curl walk. Chrome DevTools QA pass for UI changes.

---

## 11. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Operator draws self-intersecting polygon → UI lets them save → resolver crashes | Low | Medium | Server-side validation rejects via NetTopologySuite `IsValid`. UI validation is hinting only. |
| Point exactly on zone edge | Medium | Low | NetTopologySuite `Contains` excludes edge points; we use `Covers` which includes. Consistent behaviour both sides of every boundary. |
| Overlapping zones slipped in via direct DB edit | Low | Medium | Resolver does first-match wins. Logs warning when it happens so operators can clean up. |
| Geocoding service down + no cached coords + no stored lat/lng | Low | Low | Resolver returns null → mileage fallback runs → booking completes normally. |
| Large tenant with 500+ zones → in-memory cache bloats | Low | Low | Well below any memory concern. Revisit if any tenant approaches 10k zones. |
| CSV import malformed → partial matrix corruption | Medium | Medium | Import runs in a transaction. Any validation error aborts the whole batch with a detailed error list. |
| V1 callers break because of schema migration | Low | High | Migration is strictly additive. Every v1 endpoint re-tested in snapshot suite on PR1. |

---

## 12. Open items for implementation plan

None — all design decisions locked. Implementation plan proceeds to `docs/superpowers/plans/2026-04-16-zone-zone-pricing-plan.md` via the `writing-plans` skill.
