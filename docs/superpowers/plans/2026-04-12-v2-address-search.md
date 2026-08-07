# V2 Address Search Endpoints — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build three v2 address endpoints (search, resolve, postcode lookup) with advanced bias/filter parameters, following the existing MediatR + Result<T> + v2 envelope patterns.

**Architecture:** New v2 controller in RedTaxi.API dispatches to three new handlers in RedTaxi.Application/Features/Address/. Two new overloads added to IAddressLookupService for parameter pass-through. No changes to v1 endpoints, existing handlers, or IdealPostcodesClient.

**Tech Stack:** .NET 8, MediatR, EF Core 8, Ideal Postcodes REST API, Google Places (New) API, Verify (snapshot tests)

**Spec:** `docs/superpowers/specs/2026-04-12-v2-address-search-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `src/backend/RedTaxi.Application/Features/Address/AddressSearch.cs` | Search handler — builds provider options from request params + tenant defaults |
| Create | `src/backend/RedTaxi.Application/Features/Address/AddressResolve.cs` | Resolve handler — prefix routing with proper Result<T> error codes |
| Create | `src/backend/RedTaxi.Application/Features/Address/AddressPostcodeLookup.cs` | Postcode handler — thin Result<T> wrapper |
| Create | `src/backend/RedTaxi.API/Controllers/V2/AddressController.cs` | V2 controller — routing only, 3 actions |
| Modify | `src/backend/RedTaxi.Application/Interfaces/IAddressLookupService.cs` | Add 2 new overloads |
| Modify | `src/backend/RedTaxi.Application/Services/AddressLookupService.cs` | Implement 2 new overloads |
| Create | `src/backend/RedTaxi.Tests/SnapshotTests/AddressV2SnapshotTests.cs` | Snapshot tests for all 3 endpoints |

---

### Task 1: Service Layer Overloads

**Files:**
- Modify: `src/backend/RedTaxi.Application/Interfaces/IAddressLookupService.cs`
- Modify: `src/backend/RedTaxi.Application/Services/AddressLookupService.cs`

- [ ] **Step 1: Add IdealSearchAddress overload to interface**

In `IAddressLookupService.cs`, add one new method after the existing `IdealSearchAddress`:

```csharp
Task<List<AddressSuggestion>> IdealSearchAddress(string query, AutocompleteOptions options);
```

This requires a using directive for `RedTaxi.Domain.IdealPostcodes` at the top of the interface file.

- [ ] **Step 2: Add GoogleSearchAsync overload to interface**

In `IAddressLookupService.cs`, add one new method after the existing `GoogleSearchAsync`:

```csharp
Task<IReadOnlyList<AddressSuggestion>> GoogleSearchAsync(
    string q, string sessionToken, CancellationToken ct,
    double overrideCenterLat, double overrideCenterLng, double overrideRadiusMeters);
```

- [ ] **Step 3: Implement IdealSearchAddress overload**

In `AddressLookupService.cs`, add after the existing `IdealSearchAddress` method (around line 76):

```csharp
public async Task<List<DTOs.Address.AddressSuggestion>> IdealSearchAddress(
    string query, AutocompleteOptions options)
{
    _logger.LogInformation("Searching addresses via Ideal Postcodes (v2) for query {Query}", query);

    var data = await _idealPostcodes.AutocompleteAddressAsync(query, options);

    return data.Select(item => new DTOs.Address.AddressSuggestion(
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

- [ ] **Step 4: Implement GoogleSearchAsync overload**

In `AddressLookupService.cs`, add after the existing `GoogleSearchAsync` method (around line 250). This is the same as the existing method but uses the override parameters instead of reading from tenant config:

```csharp
public async Task<IReadOnlyList<DTOs.Address.AddressSuggestion>> GoogleSearchAsync(
    string q, string sessionToken, CancellationToken ct,
    double overrideCenterLat, double overrideCenterLng, double overrideRadiusMeters)
{
    _logger.LogInformation("Searching addresses via Google Places (v2) for query {Query} with override bias", q);
    var url = "https://places.googleapis.com/v1/places:autocomplete";

    var regionCode = await _tenantConfig.GetAsync("GooglePlacesRegionCode", "GB");

    var body = new
    {
        input = q,
        includedRegionCodes = new[] { regionCode },
        locationBias = new
        {
            circle = new
            {
                center = new { latitude = overrideCenterLat, longitude = overrideCenterLng },
                radius = overrideRadiusMeters
            }
        },
        origin = new { latitude = overrideCenterLat, longitude = overrideCenterLng },
        sessionToken = sessionToken,
        regionCode = regionCode,
        languageCode = "en-GB"
    };

    using var req = new HttpRequestMessage(HttpMethod.Post, url);
    req.Headers.Add("X-Goog-Api-Key", _googlePlacesApiKey);
    req.Headers.Add("X-Goog-FieldMask",
        "suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.distanceMeters");
    req.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");

    using var res = await _http.SendAsync(req, ct);
    var responseBody = await res.Content.ReadAsStringAsync(ct);

    if (!res.IsSuccessStatusCode)
    {
        _logger.LogError("Google Places error {StatusCode}: {Body}", (int)res.StatusCode, responseBody);
        throw new HttpRequestException($"Google Places returned {(int)res.StatusCode}: {responseBody}");
    }

    using var doc = JsonDocument.Parse(responseBody);
    var list = new List<DTOs.Address.AddressSuggestion>();

    if (doc.RootElement.TryGetProperty("suggestions", out var suggestions)
        && suggestions.ValueKind == JsonValueKind.Array)
    {
        foreach (var item in suggestions.EnumerateArray())
        {
            if (!item.TryGetProperty("placePrediction", out var pp)) continue;
            var placeId = pp.TryGetProperty("placeId", out var pid) ? pid.GetString() : null;
            var text = pp.TryGetProperty("text", out var t) && t.TryGetProperty("text", out var tt)
                ? tt.GetString() : null;
            if (string.IsNullOrWhiteSpace(placeId) || string.IsNullOrWhiteSpace(text)) continue;

            list.Add(new DTOs.Address.AddressSuggestion(
                Id: $"g:{placeId}", Label: text!, Type: "google",
                SecondaryText: null, Lat: null, Lng: null, Name: null, Postcode: null));
        }
    }

    return list;
}
```

- [ ] **Step 5: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Application/RedTaxi.Application.csproj --no-restore`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add src/backend/RedTaxi.Application/Interfaces/IAddressLookupService.cs \
        src/backend/RedTaxi.Application/Services/AddressLookupService.cs
git commit -m "feat(address): add v2 overloads to IAddressLookupService for advanced params"
```

---

### Task 2: AddressSearch Handler

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/Address/AddressSearch.cs`

- [ ] **Step 1: Create the handler file**

```csharp
using MediatR;
using RedTaxi.Domain;
using RedTaxi.Domain.IdealPostcodes;
using RedTaxi.DTOs.Address;
using RedTaxi.Interfaces;
using Serilog;

namespace RedTaxi.Application.Features.Address;

public static class AddressSearch
{
    public record Query(
        string Q,
        string? SessionToken,
        int? Limit,
        // Bias (soft)
        string? BiasPostcodeOutward,
        string? BiasPostTown,
        string? BiasLonLat,
        // Filters (hard)
        string? FilterPostcodeArea,
        string? FilterPostTown,
        string? FilterPostcodeOutward,
        bool? FilterResidentialOnly
    ) : IRequest<Result<SearchResult>>;

    public record SearchResult(
        List<AddressSuggestion> Suggestions,
        string Provider,
        int Count);

    public class Handler : IRequestHandler<Query, Result<SearchResult>>
    {
        private readonly IAddressLookupService _service;
        private readonly ITenantConfigService _tenantConfig;

        public Handler(IAddressLookupService service, ITenantConfigService tenantConfig)
        {
            _service = service;
            _tenantConfig = tenantConfig;
        }

        public async Task<Result<SearchResult>> Handle(Query request, CancellationToken ct)
        {
            var log = Log.ForContext("Feature", "AddressSearch");

            if (string.IsNullOrWhiteSpace(request.Q) || request.Q.Trim().Length < 3)
                return Result.Fail<SearchResult>("QUERY_TOO_SHORT");

            try
            {
                var provider = await _tenantConfig.GetAsync("AddressProvider", "ideal");
                log.Information("[AddressSearch] query='{Query}' provider={Provider}", request.Q, provider);

                List<AddressSuggestion> results;

                if (provider == "google")
                {
                    var sessionToken = request.SessionToken ?? Guid.NewGuid().ToString("N");
                    results = await SearchGoogle(request, sessionToken, ct);
                }
                else
                {
                    results = await SearchIdeal(request);
                }

                log.Information("[AddressSearch] returned {Count} results via {Provider}", results.Count, provider);
                return Result.Ok(new SearchResult(results, provider, results.Count));
            }
            catch (Exception ex)
            {
                log.Error(ex, "[AddressSearch] failed for query='{Query}'", request.Q);
                return Result.Fail<SearchResult>("SEARCH_FAILED");
            }
        }

        private async Task<List<AddressSuggestion>> SearchIdeal(Query req)
        {
            var limit = req.Limit
                ?? (int)await _tenantConfig.GetDecimalAsync("AddressLookupLimit", 20);
            var biasOutward = req.BiasPostcodeOutward
                ?? await _tenantConfig.GetAsync("BiasPostcodeOutward", "SP8,SP7");
            var postcodeArea = req.FilterPostcodeArea
                ?? await _tenantConfig.GetAsync("PostcodeArea", "SP,BA,DT");

            var options = new AutocompleteOptions
            {
                Limit = limit,
                BiasPostcodeOutward = biasOutward,
                PostcodeArea = postcodeArea,
                // New v2 params
                BiasPostTown = req.BiasPostTown,
                BiasLonLat = req.BiasLonLat,
                PostTown = req.FilterPostTown,
                PostcodeOutward = req.FilterPostcodeOutward,
                IsResidential = req.FilterResidentialOnly,
            };

            return await _service.IdealSearchAddress(req.Q, options);
        }

        private async Task<List<AddressSuggestion>> SearchGoogle(
            Query req, string sessionToken, CancellationToken ct)
        {
            // If biasLonLat provided, parse and use override
            if (!string.IsNullOrEmpty(req.BiasLonLat))
            {
                var parts = req.BiasLonLat.Split(',');
                if (parts.Length == 3
                    && double.TryParse(parts[0], out var lon)
                    && double.TryParse(parts[1], out var lat)
                    && double.TryParse(parts[2], out var radius))
                {
                    var overrideResults = await _service.GoogleSearchAsync(
                        req.Q, sessionToken, ct, lat, lon, radius);
                    return overrideResults.ToList();
                }
            }

            // Default: use tenant config centre/radius
            var defaultResults = await _service.GoogleSearchAsync(req.Q, sessionToken, ct);
            return defaultResults.ToList();
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Application/RedTaxi.Application.csproj --no-restore`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/Address/AddressSearch.cs
git commit -m "feat(address): add AddressSearch handler with advanced bias/filter params"
```

---

### Task 3: AddressResolve Handler

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/Address/AddressResolve.cs`

- [ ] **Step 1: Create the handler file**

```csharp
using MediatR;
using RedTaxi.Domain;
using RedTaxi.DTOs.Address;
using RedTaxi.Interfaces;
using Serilog;

namespace RedTaxi.Application.Features.Address;

public static class AddressResolve
{
    public record Query(string Id, string? SessionToken) : IRequest<Result<ResolvedAddress>>;

    public class Handler : IRequestHandler<Query, Result<ResolvedAddress>>
    {
        private readonly IAddressLookupService _service;

        public Handler(IAddressLookupService service)
        {
            _service = service;
        }

        public async Task<Result<ResolvedAddress>> Handle(Query request, CancellationToken ct)
        {
            var log = Log.ForContext("Feature", "AddressResolve");

            if (string.IsNullOrWhiteSpace(request.Id))
                return Result.Fail<ResolvedAddress>("MISSING_ID");

            log.Information("[AddressResolve] resolving Id={Id}", request.Id);

            try
            {
                if (request.Id.StartsWith("p:", StringComparison.OrdinalIgnoreCase))
                {
                    var poi = await _service.ResolvePOIAsync(request.Id[2..]);
                    log.Information("[AddressResolve] resolved POI for Id={Id}", request.Id);
                    return Result.Ok(poi);
                }

                if (request.Id.StartsWith("g:", StringComparison.OrdinalIgnoreCase))
                {
                    if (string.IsNullOrWhiteSpace(request.SessionToken))
                        return Result.Fail<ResolvedAddress>("SESSION_REQUIRED");

                    var resolved = await _service.ResolveGooglePlaceAsync(
                        request.Id[2..], request.SessionToken, ct);
                    log.Information("[AddressResolve] resolved Google place for Id={Id}", request.Id);
                    return Result.Ok(resolved);
                }

                if (request.Id.StartsWith("i:", StringComparison.OrdinalIgnoreCase))
                {
                    var resolved = await _service.ResolveIdealAddressAsync(request.Id[2..], ct);
                    log.Information("[AddressResolve] resolved Ideal address for Id={Id}", request.Id);
                    return Result.Ok(resolved);
                }

                log.Warning("[AddressResolve] unknown id format for Id={Id}", request.Id);
                return Result.Fail<ResolvedAddress>("UNKNOWN_ID_FORMAT");
            }
            catch (Exception ex)
            {
                log.Error(ex, "[AddressResolve] failed for Id={Id}", request.Id);
                return Result.Fail<ResolvedAddress>("RESOLVE_FAILED");
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Application/RedTaxi.Application.csproj --no-restore`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/Address/AddressResolve.cs
git commit -m "feat(address): add AddressResolve handler with UPPER_SNAKE_CASE error codes"
```

---

### Task 4: AddressPostcodeLookup Handler

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/Address/AddressPostcodeLookup.cs`

- [ ] **Step 1: Create the handler file**

```csharp
using MediatR;
using RedTaxi.Domain;
using RedTaxi.DTOs.Address;
using RedTaxi.Interfaces;
using Serilog;

namespace RedTaxi.Application.Features.Address;

public static class AddressPostcodeLookup
{
    public record Query(string Postcode) : IRequest<Result<LookupResult>>;

    public record LookupResult(
        List<AddressSuggestion> Suggestions,
        string Provider,
        int Count);

    public class Handler : IRequestHandler<Query, Result<LookupResult>>
    {
        private readonly IAddressLookupService _service;
        private readonly ITenantConfigService _tenantConfig;

        public Handler(IAddressLookupService service, ITenantConfigService tenantConfig)
        {
            _service = service;
            _tenantConfig = tenantConfig;
        }

        public async Task<Result<LookupResult>> Handle(Query request, CancellationToken ct)
        {
            var log = Log.ForContext("Feature", "AddressPostcodeLookup");

            if (string.IsNullOrWhiteSpace(request.Postcode) || request.Postcode.Trim().Length < 5)
                return Result.Fail<LookupResult>("INVALID_POSTCODE");

            try
            {
                var provider = await _tenantConfig.GetAsync("AddressProvider", "ideal");
                log.Information("[AddressPostcodeLookup] postcode={Postcode} provider={Provider}",
                    request.Postcode, provider);

                List<AddressSuggestion> results;

                if (provider == "google")
                {
                    var sessionToken = Guid.NewGuid().ToString("N");
                    var googleResults = await _service.GoogleSearchAsync(
                        request.Postcode, sessionToken, ct);
                    results = googleResults.ToList();
                }
                else
                {
                    results = await _service.IdealPostcodeSearch(request.Postcode);
                }

                log.Information("[AddressPostcodeLookup] returned {Count} results via {Provider}",
                    results.Count, provider);
                return Result.Ok(new LookupResult(results, provider, results.Count));
            }
            catch (Exception ex)
            {
                log.Error(ex, "[AddressPostcodeLookup] failed for postcode={Postcode}", request.Postcode);
                return Result.Fail<LookupResult>("LOOKUP_FAILED");
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Application/RedTaxi.Application.csproj --no-restore`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/Address/AddressPostcodeLookup.cs
git commit -m "feat(address): add AddressPostcodeLookup handler with Result<T>"
```

---

### Task 5: V2 Address Controller

**Files:**
- Create: `src/backend/RedTaxi.API/Controllers/V2/AddressController.cs`

- [ ] **Step 1: Create the controller file**

```csharp
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using RedTaxi.API.Extensions;
using RedTaxi.Application.Features.Address;

namespace RedTaxi.API.Controllers.V2;

[Route("api/v2/address")]
[ApiController]
[ApiExplorerSettings(GroupName = "v2")]
[Authorize]
public class AddressController : ControllerBase
{
    private readonly IMediator _mediator;

    public AddressController(IMediator mediator)
    {
        _mediator = mediator;
    }

    public record SearchRequest(
        string Query,
        string? SessionToken = null,
        int? Limit = null,
        string? BiasPostcodeOutward = null,
        string? BiasPostTown = null,
        string? BiasLonLat = null,
        string? FilterPostcodeArea = null,
        string? FilterPostTown = null,
        string? FilterPostcodeOutward = null,
        bool? FilterResidentialOnly = null);

    [HttpPost("search")]
    public async Task<IActionResult> Search([FromBody] SearchRequest body)
    {
        var result = await _mediator.Send(new AddressSearch.Query(
            Q: body.Query?.Trim() ?? "",
            SessionToken: body.SessionToken,
            Limit: body.Limit,
            BiasPostcodeOutward: body.BiasPostcodeOutward,
            BiasPostTown: body.BiasPostTown,
            BiasLonLat: body.BiasLonLat,
            FilterPostcodeArea: body.FilterPostcodeArea,
            FilterPostTown: body.FilterPostTown,
            FilterPostcodeOutward: body.FilterPostcodeOutward,
            FilterResidentialOnly: body.FilterResidentialOnly));

        return result.ToActionResult(400, "SEARCH_FAILED");
    }

    [HttpGet("resolve")]
    public async Task<IActionResult> Resolve(
        [FromQuery] string id,
        [FromQuery] string? sessionToken = null)
    {
        var result = await _mediator.Send(new AddressResolve.Query(id ?? "", sessionToken));
        return result.ToActionResult(400, "RESOLVE_FAILED");
    }

    [HttpGet("postcode/{postcode}")]
    public async Task<IActionResult> PostcodeLookup(string postcode)
    {
        var result = await _mediator.Send(new AddressPostcodeLookup.Query(postcode?.Trim() ?? ""));
        return result.ToActionResult(400, "LOOKUP_FAILED");
    }
}
```

- [ ] **Step 2: Build the entire solution**

Run: `cd src/backend && dotnet build --no-restore`
Expected: 0 errors (warnings are pre-existing and OK)

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.API/Controllers/V2/AddressController.cs
git commit -m "feat(address): add v2 AddressController with search, resolve, postcode endpoints"
```

---

### Task 6: Snapshot Tests

**Files:**
- Create: `src/backend/RedTaxi.Tests/SnapshotTests/AddressV2SnapshotTests.cs`

- [ ] **Step 1: Create the test file**

These tests use the existing `ApiFixture` + `SnapshotTestBase` pattern. Address search hits external APIs so we test the envelope shape and error handling rather than live results. The search test will return results from the test DB's Ideal Postcodes key (or empty list if no key configured in test).

```csharp
using System.Net;
using FluentAssertions;

namespace RedTaxi.Tests.SnapshotTests;

[Collection("Api")]
public class AddressV2SnapshotTests : SnapshotTestBase
{
    public AddressV2SnapshotTests(ApiFixture fixture) : base(fixture) { }

    // ======================================================================
    // SEARCH
    // ======================================================================

    [Fact]
    public async Task V2_Address_Search_QueryTooShort()
    {
        var response = await RawPost("/api/v2/address/search", new { query = "AB" });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Search_MissingQuery()
    {
        var response = await RawPost("/api/v2/address/search", new { query = "" });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Search_Unauthenticated()
    {
        var response = await RawPost("/api/v2/address/search",
            new { query = "Addison Close" }, auth: false);
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    // ======================================================================
    // RESOLVE
    // ======================================================================

    [Fact]
    public async Task V2_Address_Resolve_MissingId()
    {
        var response = await RawGet("/api/v2/address/resolve?id=");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Resolve_UnknownFormat()
    {
        var response = await RawGet("/api/v2/address/resolve?id=x:unknown");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Resolve_GoogleWithoutSession()
    {
        var response = await RawGet("/api/v2/address/resolve?id=g:ChIJtest123");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Resolve_Unauthenticated()
    {
        var response = await RawGet("/api/v2/address/resolve?id=i:test", auth: false);
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    // ======================================================================
    // POSTCODE
    // ======================================================================

    [Fact]
    public async Task V2_Address_Postcode_InvalidPostcode()
    {
        var response = await RawGet("/api/v2/address/postcode/AB");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
        var json = await response.Content.ReadAsStringAsync();
        await VerifyJson(json);
    }

    [Fact]
    public async Task V2_Address_Postcode_Unauthenticated()
    {
        var response = await RawGet("/api/v2/address/postcode/SP8%204QS", auth: false);
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

}
```

Note: `RawPost` and `RawGet` are inherited from `SnapshotTestBase` — do NOT redefine them.
```

- [ ] **Step 2: Run the tests**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~AddressV2SnapshotTests" --no-restore`

First run will fail on snapshot verification — the `.verified.json` files don't exist yet.

- [ ] **Step 3: Accept the snapshots**

Review each generated `.received.json` file in `src/backend/RedTaxi.Tests/SnapshotTests/`. Verify the response shapes are correct v2 envelopes, then rename `.received.json` → `.verified.json` for each test.

- [ ] **Step 4: Re-run tests to confirm green**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~AddressV2SnapshotTests" --no-restore`
Expected: all tests pass

- [ ] **Step 5: Commit**

```bash
git add src/backend/RedTaxi.Tests/SnapshotTests/AddressV2SnapshotTests.cs \
        src/backend/RedTaxi.Tests/SnapshotTests/*.verified.json
git commit -m "test(address): add v2 address endpoint snapshot tests"
```

---

### Task 7: Wire AI Agent to v2 Search

**Files:**
- Modify: `src/backend/RedTaxi.AI/Controllers/AiAgentController.cs`

- [ ] **Step 1: Update the fallback search in LookupAddressTool**

In `AiAgentController.cs`, find the section after the intelligence MISS log (around line 569) where it falls through to `WebBookerSearch.Query`. Replace the `WebBookerSearch` call with `AddressSearch.Query`, passing the core outward codes as bias:

Change from:
```csharp
var suggestions = await _mediator.Send(new WebBookerSearch.Query(query, sessionToken), ct);
```

To:
```csharp
// Read bias from tenant config instead of hardcoded coreOutwards
var biasOutward = await _tenantConfig.GetAsync("BiasPostcodeOutward", "SP8,SP7");

var searchResult = await _mediator.Send(new AddressSearch.Query(
    Q: query,
    SessionToken: sessionToken,
    Limit: null,
    BiasPostcodeOutward: biasOutward,
    BiasPostTown: null,
    BiasLonLat: null,
    FilterPostcodeArea: null,
    FilterPostTown: null,
    FilterPostcodeOutward: null,
    FilterResidentialOnly: null), ct);
var suggestions = searchResult.Success ? searchResult.Value?.Suggestions : null;
```

Add the using directive at the top of the file:
```csharp
using RedTaxi.Application.Features.Address;
```

Also update the null-check on `suggestions` — the existing code checks `suggestions == null || suggestions.Count == 0`; adjust to match the new shape.

Note: `_tenantConfig` is an `ITenantConfigService` — verify it's already injected into `AiAgentController`. If not, add it to the constructor.

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.AI/RedTaxi.AI.csproj --no-restore`
Expected: 0 errors

- [ ] **Step 3: Run all AI agent tests**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~AiAgent|FullyQualifiedName~AddressV2" --no-restore`
Expected: all pass

- [ ] **Step 4: Commit**

```bash
git add src/backend/RedTaxi.AI/Controllers/AiAgentController.cs
git commit -m "feat(voice-agent): switch address fallback from WebBookerSearch to v2 AddressSearch"
```

---

### Task 8: Manual Staging Test

**Files:** None (testing only)

- [ ] **Step 1: Publish and restart staging**

```bash
powershell -Command "nssm stop redtaxi-api"
cd src/backend && dotnet publish RedTaxi.API/RedTaxi.API.csproj -c Release -o ../../staging/api-publish --no-restore
powershell -Command "nssm start redtaxi-api"
```

- [ ] **Step 2: Verify health**

```bash
curl -s https://staging-api.redtaxi.co.uk/health
```
Expected: `{"status":"healthy",...}`

- [ ] **Step 3: Test v2 search with bias**

```bash
curl -s -X POST https://staging-api.redtaxi.co.uk/api/v2/address/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(curl -s https://staging-api.redtaxi.co.uk/dev/token?user=Peter | jq -r '.token')" \
  -d '{"query":"Addison Close","biasPostTown":"Gillingham"}' | python -m json.tool
```
Expected: v2 envelope with suggestions containing "Addison Close, Gillingham"

- [ ] **Step 4: Test v2 search with filter**

```bash
curl -s -X POST https://staging-api.redtaxi.co.uk/api/v2/address/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"Kingfisher Avenue","filterPostcodeOutward":"SP8"}' | python -m json.tool
```
Expected: v2 envelope with local results only

- [ ] **Step 5: Test v2 resolve**

Take an `id` from the search response and resolve it:

```bash
curl -s "https://staging-api.redtaxi.co.uk/api/v2/address/resolve?id=i:THE_ID" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```
Expected: full address with postcode, lat/lng, townCity

- [ ] **Step 6: Test v2 postcode lookup**

```bash
curl -s "https://staging-api.redtaxi.co.uk/api/v2/address/postcode/SP8%204QS" \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```
Expected: v2 envelope with all addresses at SP8 4QS

- [ ] **Step 7: Test voice agent with "Addison Close"**

Use the tuning harness at `http://localhost:5999/`. Call and say "I need a taxi from Addison Close to Tesco". Verify:
- "Addison Close" resolves via the new v2 search path
- Check staging logs for `[AddressSearch]` log entries

- [ ] **Step 8: Push all changes**

```bash
git push origin feature/intelligence-iteration-2
```
