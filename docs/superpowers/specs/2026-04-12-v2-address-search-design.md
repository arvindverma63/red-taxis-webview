# V2 Address Search Endpoints — Design Spec

**Date:** 2026-04-12
**Status:** Draft
**Author:** Peter Farrell + Claude

---

## Problem

The v1 address endpoints (`/api/Address/*`) are unauthenticated GETs with no v2 envelope, and they only pass a subset of the provider API parameters. When the AI voice agent (or dispatch frontend) needs to search for a residential street like "Addison Close", the backend can't tell the provider to bias or filter by town, geo-point, or address type — so results are broad and sometimes miss the local match.

Both Ideal Postcodes and Google Places (New) support rich locality parameters that we don't currently expose:

- **Ideal**: `bias_post_town`, `bias_lonlat`, `post_town` (hard filter), `postcode_outward` (hard filter), `is_residential`, `box`
- **Google**: `locationBias` (circle with centre + radius), `locationRestriction` (hard rectangle), `includedType`, `regionCode`

## Solution

Build three new v2 address endpoints in `RedTaxi.API` that mirror the v1 flow (search → resolve, postcode lookup) but add:

1. V2 envelope (`success`, `data`, `errors`)
2. `[Authorize]` authentication
3. Optional bias and filter parameters the consumer can pass per-request
4. Tenant config defaults applied server-side when optional params are omitted

**No changes to v1 endpoints.** V1 continues to work identically. The new handlers call the existing `IAddressLookupService` and `IdealPostcodesClient` — no changes to the infrastructure layer.

---

## Endpoints

### 1. `POST /api/v2/address/search`

Primary address search. POST because the optional params are a structured body, not a query string.

**Request body:**

```json
{
  "query": "Addison Close",

  "sessionToken": "abc123",

  "limit": 10,

  "biasPostcodeOutward": "SP7,SP8",
  "biasPostTown": "Gillingham",
  "biasLonLat": "-2.2769,51.0478,20000",

  "filterPostcodeArea": "SP,BA,DT",
  "filterPostTown": "Gillingham",
  "filterPostcodeOutward": "SP8",
  "filterResidentialOnly": true
}
```

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `query` | Yes | — | Free-text search string (min 3 chars) |
| `sessionToken` | No | auto-generated GUID | Google billing session token |
| `limit` | No | tenant `AddressLookupLimit` (20) | Max suggestions to return |
| `biasPostcodeOutward` | No | tenant `BiasPostcodeOutward` | Soft boost by postcode district |
| `biasPostTown` | No | — | Soft boost by town name (Ideal: `bias_post_town`) |
| `biasLonLat` | No | — | Soft boost by geo-point: `lon,lat,radius_metres` (Ideal: `bias_lonlat`, Google: adjusted circle centre+radius) |
| `filterPostcodeArea` | No | tenant `PostcodeArea` | Hard filter by postcode area (Ideal: `postcode_area`) |
| `filterPostTown` | No | — | Hard filter by town (Ideal: `post_town`) |
| `filterPostcodeOutward` | No | — | Hard filter by outward code (Ideal: `postcode_outward`) |
| `filterResidentialOnly` | No | false | Residential addresses only (Ideal: `is_residential`) |

**Parameter mapping by provider:**

| Request param | Ideal Postcodes | Google Places |
|---------------|-----------------|---------------|
| `biasPostcodeOutward` | `bias_postcode_outward` | — (not applicable) |
| `biasPostTown` | `bias_post_town` | — |
| `biasLonLat` | `bias_lonlat` (lon,lat,radius) | `locationBias.circle` (override centre+radius) |
| `filterPostcodeArea` | `postcode_area` | — |
| `filterPostTown` | `post_town` | — |
| `filterPostcodeOutward` | `postcode_outward` | — |
| `filterResidentialOnly` | `is_residential=true` | — |

Google Places has fewer filter options — Ideal-specific filters are silently ignored when provider is Google. The `biasLonLat` param maps to Google's `locationBias` circle, overriding the tenant's default centre and radius.

**Response (v2 envelope):**

```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "id": "i:paf_28191881",
        "label": "3 Addison Close, Gillingham, Dorset, SP8 4QS",
        "type": "ideal",
        "postcode": null,
        "lat": null,
        "lng": null,
        "name": null
      }
    ],
    "provider": "ideal",
    "count": 5
  },
  "errors": []
}
```

The `suggestions` array uses the existing `AddressSuggestion` DTO shape. The `id` field is prefixed (`i:` / `g:`) for provider routing in the resolve step.

**Error codes:**

| Code | Status | When |
|------|--------|------|
| `QUERY_TOO_SHORT` | 400 | query < 3 characters |
| `SEARCH_FAILED` | 500 | provider API error |

---

### 2. `GET /api/v2/address/resolve`

Resolves a suggestion ID to a full address with postcode, lat/lng, and address components.

**Query parameters:**

| Param | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Suggestion ID from search (prefixed: `i:`, `g:`, `p:`) |
| `sessionToken` | No | Required for Google (`g:`) IDs |

**Response (v2 envelope):**

```json
{
  "success": true,
  "data": {
    "displayLabel": "3 Addison Close, Gillingham, SP8 4QS",
    "placeName": null,
    "formattedAddress": "3 Addison Close, Gillingham, Dorset, SP8 4QS",
    "postcode": "SP8 4QS",
    "line1": "3 Addison Close",
    "line2": null,
    "townCity": "Gillingham",
    "county": "Dorset",
    "lat": 51.0365,
    "lng": -2.2741,
    "source": "ideal",
    "googlePlaceId": null
  },
  "errors": []
}
```

Uses the existing `ResolvedAddress` record. Prefix routing logic is identical to the existing `ResolveAddress` handler.

**Note:** The v2 controller does NOT reuse the existing `ResolveAddress` handler directly (it returns freeform error strings). Instead, a new `AddressResolve` handler wraps the same service calls but returns proper `Result<ResolvedAddress>` with UPPER_SNAKE_CASE error codes.

**Error codes:**

| Code | Status | When |
|------|--------|------|
| `MISSING_ID` | 400 | `id` param empty |
| `SESSION_REQUIRED` | 400 | Google ID without sessionToken |
| `UNKNOWN_ID_FORMAT` | 400 | ID prefix not recognised |
| `RESOLVE_FAILED` | 500 | Provider API error |

---

### 3. `GET /api/v2/address/postcode/{postcode}`

Returns all addresses at a given postcode.

**Path parameter:**

| Param | Required | Description |
|-------|----------|-------------|
| `postcode` | Yes | UK postcode (e.g. `SP8 4QS`) |

**Response (v2 envelope):**

```json
{
  "success": true,
  "data": {
    "suggestions": [
      {
        "id": "",
        "label": "1 Addison Close, Gillingham, SP8 4QS",
        "type": "",
        "postcode": "SP8 4QS",
        "lat": null,
        "lng": null,
        "name": null
      }
    ],
    "provider": "ideal",
    "count": 12
  },
  "errors": []
}
```

**Error codes:**

| Code | Status | When |
|------|--------|------|
| `INVALID_POSTCODE` | 400 | Postcode empty or malformed |
| `LOOKUP_FAILED` | 500 | Provider API error |

---

## Implementation Structure

### Controller

**File:** `src/backend/RedTaxi.API/Controllers/V2/AddressController.cs`

```
[Route("api/v2/address")]
[ApiController]
[ApiExplorerSettings(GroupName = "v2")]
[Authorize]
public class AddressController : ControllerBase
```

Three actions — each dispatches to a MediatR handler and uses `ToActionResult()`:

- `[HttpPost("search")]` → `AddressSearch.Query`
- `[HttpGet("resolve")]` → `AddressResolve.Query`
- `[HttpGet("postcode/{postcode}")]` → `AddressPostcodeLookup.Query`

Controller is routing-only. No business logic, no direct DB access. Under 80 lines.

### Handlers

All in `src/backend/RedTaxi.Application/Features/Address/`:

**1. `AddressSearch.cs`**

```csharp
public static class AddressSearch
{
    public record Query(
        string Q,
        string? SessionToken,
        int? Limit,
        // Bias
        string? BiasPostcodeOutward,
        string? BiasPostTown,
        string? BiasLonLat,
        // Filters
        string? FilterPostcodeArea,
        string? FilterPostTown,
        string? FilterPostcodeOutward,
        bool? FilterResidentialOnly
    ) : IRequest<Result<AddressSearchResult>>;

    public record AddressSearchResult(
        List<AddressSuggestion> Suggestions,
        string Provider,
        int Count);

    public class Handler : IRequestHandler<Query, Result<AddressSearchResult>>
    {
        // Inject IAddressLookupService + ITenantConfigService
        // 1. Read provider from tenant config
        // 2. Build provider-specific options from query params + tenant defaults
        // 3. Call existing service methods
        // 4. Return Result<AddressSearchResult>
    }
}
```

The handler builds an `AutocompleteOptions` for Ideal (merging request params with tenant defaults) or adjusts the Google circle bias from `biasLonLat`. It calls the **existing** `IAddressLookupService.IdealSearchAddress()` or `GoogleSearchAsync()`.

**Key change:** `IdealSearchAddress()` currently builds its own `AutocompleteOptions` internally from tenant config. The new handler needs to pass options through. Two approaches:

- **Option A (preferred):** Add a new overload `IdealSearchAddress(string query, AutocompleteOptions options)` to `IAddressLookupService` that accepts pre-built options. The existing parameterless overload continues to build options from tenant config (v1 unchanged).
- **Option B:** Pass all params individually. Noisier, harder to extend.

**2. `AddressResolve.cs`**

New handler wrapping the same `IAddressLookupService` calls as the existing `ResolveAddress` handler but with proper UPPER_SNAKE_CASE error codes in `Result.Fail()`. The existing handler uses freeform strings which don't match v2 error code standards.

```csharp
public static class AddressResolve
{
    public record Query(string Id, string? SessionToken) : IRequest<Result<ResolvedAddress>>;

    public class Handler : IRequestHandler<Query, Result<ResolvedAddress>>
    {
        // Same prefix-routing logic (i:/g:/p:) calling the same service methods
        // but returns Result.Fail("SESSION_REQUIRED", "...") etc.
    }
}
```

**3. `AddressPostcodeLookup.cs`**

New handler wrapping existing postcode lookup but returning `Result<T>`. The existing `PostcodeLookup` handler returns raw `List<AddressSuggestion>` (non-Result).

```csharp
public static class AddressPostcodeLookup
{
    public record Query(string Postcode) : IRequest<Result<PostcodeLookupResult>>;

    public record PostcodeLookupResult(
        List<AddressSuggestion> Suggestions,
        string Provider,
        int Count);

    public class Handler : IRequestHandler<Query, Result<PostcodeLookupResult>>
    {
        // Delegates to IAddressLookupService.IdealPostcodeSearch() or GoogleSearchAsync()
    }
}
```

### Service Layer Changes

**`IAddressLookupService`** — add one new method:

```csharp
Task<List<AddressSuggestion>> IdealSearchAddress(string query, AutocompleteOptions options);
```

**`AddressLookupService`** — implement the new overload:

```csharp
public async Task<List<AddressSuggestion>> IdealSearchAddress(string query, AutocompleteOptions options)
{
    // Same as existing IdealSearchAddress but uses the provided options
    // instead of building from tenant config
    var data = await _idealPostcodes.AutocompleteAddressAsync(query, options);
    return data.Select(item => new AddressSuggestion(
        Id: $"i:{item.Id}",
        Label: item.Suggestion,
        Type: "ideal",
        SecondaryText: null,
        Lat: null,
        Lng: null,
        Name: null,
        Postcode: ""
    )).ToList();
}
```

**`GoogleSearchAsync`** — add a **new overload** (the existing 3-param signature is unchanged):

```csharp
// New overload — existing GoogleSearchAsync(q, sessionToken, ct) remains untouched
Task<IReadOnlyList<AddressSuggestion>> GoogleSearchAsync(
    string q, string sessionToken, CancellationToken ct,
    double overrideCenterLat, double overrideCenterLng, double overrideRadiusMeters);
```

The existing call continues to read centre/radius from tenant config. The new overload is only used when the handler has `biasLonLat` to pass.

**`biasLonLat` parsing:** The handler parses `"lon,lat,radius"` (e.g. `"-2.2769,51.0478,20000"`) by splitting on comma → `[lon, lat, radius_metres]`. For Ideal, the string is passed to `AutocompleteOptions.BiasLonLat` as-is. For Google, it is parsed into `overrideCenterLat`, `overrideCenterLng`, `overrideRadiusMeters`.

---

## How the AI Agent Uses This

The AI agent's `lookup_address` tool in `AiAgentController` currently has its own search logic (intelligence → WebBookerSearch → locality filter). The v2 endpoints don't replace that orchestration — they replace the **fallback search step**.

Current flow:
```
lookup_address("Addison Close")
  → Intelligence lookup → MISS
  → WebBookerSearch.Query("Addison Close") → Ideal API (tenant defaults only)
  → Locality filter → Return
```

New flow:
```
lookup_address("Addison Close")
  → Intelligence lookup → MISS
  → AddressSearch.Query("Addison Close", biasPostcodeOutward: "SP7,SP8") → Ideal API (with bias)
  → Locality filter → Return
```

The AI agent controller switches from calling `WebBookerSearch.Query` to `AddressSearch.Query`, passing the core outward codes as bias parameters. Later, when the street DB is ready, it slots in between intelligence and external API search — no endpoint changes needed.

---

## What Changes

| Component | Change |
|-----------|--------|
| `RedTaxi.API/Controllers/V2/AddressController.cs` | **New file** — 3 endpoints |
| `RedTaxi.Application/Features/Address/AddressSearch.cs` | **New file** — search handler with advanced params |
| `RedTaxi.Application/Features/Address/AddressResolve.cs` | **New file** — resolve handler with proper error codes |
| `RedTaxi.Application/Features/Address/AddressPostcodeLookup.cs` | **New file** — postcode handler returning Result<T> |
| `IAddressLookupService` | Add `IdealSearchAddress(query, options)` + `GoogleSearchAsync` overloads |
| `AddressLookupService` | Implement new overloads |
| `AiAgentController.LookupAddressTool` | Switch fallback from `WebBookerSearch` to `AddressSearch` |

## What Does Not Change

| Component | Status |
|-----------|--------|
| v1 AddressController | Untouched |
| WebBookerSearch handler | Untouched |
| ResolveAddress handler | Untouched (v1 continues using it) |
| PostcodeLookup handler | Untouched (v1 continues using it) |
| IdealPostcodesClient | Untouched (already supports all params) |
| AutocompleteOptions class | Untouched |
| AddressSuggestion / ResolvedAddress DTOs | Untouched |

---

## Testing

### Unit/Integration Tests

Add to `RedTaxi.Tests`:

1. **AddressSearch handler test** — verify Ideal options are built correctly from request params + tenant defaults
2. **AddressSearch handler test** — verify Google override params are passed through
3. **V2 endpoint snapshot tests** — `POST /api/v2/address/search`, `GET /api/v2/address/resolve`, `GET /api/v2/address/postcode/{postcode}`
4. **AI agent integration** — verify `lookup_address` with street name returns results via new path

### Manual Testing

- Call `POST /api/v2/address/search` with `biasPostTown: "Gillingham"` and query `"Addison Close"` — verify Addison Close, Gillingham appears
- Call without bias params — verify tenant defaults are applied
- Call with `filterPostTown: "Gillingham"` — verify only Gillingham results
- Call resolve with returned ID — verify full address with postcode + lat/lng
- Test via voice agent tuning harness — "I want a taxi from Addison Close" should find it

---

## Future: Street Database Integration

Peter is building a sanitised database of local street addresses separately. When ready, it slots into the AI agent's lookup chain:

```
lookup_address("Addison Close")
  → Intelligence lookup (POIs) → MISS
  → Street DB lookup (residential streets) → HIT: "Addison Close, Gillingham, SP8 4QS"
  → Return (no external API call needed)
```

The v2 address endpoints don't need to change — the street DB is a new layer in the AI agent's orchestration, not in the general-purpose search endpoint. If we later want to expose the street DB to the frontend too, we add a fourth search source in the `AddressSearch` handler.
