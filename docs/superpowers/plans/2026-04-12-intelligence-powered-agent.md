# Intelligence-Powered Voice Agent — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the intelligence pipeline's 5,964 canonical locations, 1,198 aliases, and 9,878 routes into the voice agent so address lookups are faster, more accurate, and data-driven.

**Architecture:** New `IntelligenceLookup` service queries the intelligence DB tables before falling back to the existing external API (DispatchSearch). The controller's lookup_address tool gets a fast path (~2ms) for known places. The quote tool gets cached pricing for common routes. ASR keywords are regenerated from booking frequency data.

**Tech Stack:** .NET 8, EF Core 8 (LINQ — parameterised), PostgreSQL, Serilog, xUnit + FluentAssertions

**Spec:** `docs/superpowers/specs/2026-04-12-intelligence-powered-agent-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `src/backend/RedTaxi.AI/Intelligence/Services/IntelligenceLookup.cs` | Create | Core lookup: query canonical + alias tables, apply disambiguation |
| `src/backend/RedTaxi.AI/Intelligence/Services/LocalPostcodePrefixes.cs` | Create | Shared constant for local postcode area (SP7, SP8, BA8, etc.) |
| `src/backend/RedTaxi.AI/Intelligence/Jobs/AsrKeywordRefreshJob.cs` | Create | Generate dynamic ASR keywords JSON from STT bias terms |
| `src/backend/RedTaxi.AI/Dtos/AiToolDtos.cs` | Modify | Add Source, DisambiguationHint, IsAirport, AskTerminal, TerminalPrompt to LookupAddressToolResponse |
| `src/backend/RedTaxi.AI/Controllers/AiAgentController.cs` | Modify | Wire IntelligenceLookup into LookupAddressTool + route cache into QuoteTool (caller route shortcut deferred to iteration 2) |
| `src/backend/RedTaxi.API/Program.cs` | Modify | Register IIntelligenceLookup in DI |
| `src/backend/RedTaxi.AI/tuning/agent-config/system-prompt.md` | Modify | Add disambiguation, time-aware, alias correction sections |
| `src/backend/RedTaxi.AI/tuning/sync_agent.py` | Modify | Merge generated-keywords.json into agent.json on sync |
| `src/backend/RedTaxi.Tests/IntelligenceLookupTests.cs` | Create | Unit tests for lookup, disambiguation, alias fallback |
| `src/backend/RedTaxi.Tests/AsrKeywordRefreshTests.cs` | Create | Unit tests for keyword generation |

---

## Task 1: Shared constants + DTO changes

**Files:**
- Create: `src/backend/RedTaxi.AI/Intelligence/Services/LocalPostcodePrefixes.cs`
- Modify: `src/backend/RedTaxi.AI/Dtos/AiToolDtos.cs:87-91`

- [ ] **Step 1: Create LocalPostcodePrefixes constant**

```csharp
// src/backend/RedTaxi.AI/Intelligence/Services/LocalPostcodePrefixes.cs
namespace RedTaxi.AI.Intelligence.Services;

/// <summary>
/// Postcode outward codes for the operating area. Used by IntelligenceLookup
/// and the existing locality filter. Will become tenant config for multi-tenancy.
/// </summary>
public static class LocalPostcodePrefixes
{
    public static readonly string[] Values =
    {
        "SP7", "SP8", "SP3", "SP5", "BA8", "BA9", "BA10", "BA12", "DT9", "DT10", "DT11"
    };

    public static bool IsLocal(string postcode) =>
        !string.IsNullOrEmpty(postcode) &&
        Values.Any(p => postcode.StartsWith(p, StringComparison.OrdinalIgnoreCase));
}
```

- [ ] **Step 2: Add new fields to LookupAddressToolResponse**

In `src/backend/RedTaxi.AI/Dtos/AiToolDtos.cs`, replace the `LookupAddressToolResponse` record (lines 87-91):

```csharp
public record LookupAddressToolResponse
{
    public int CandidateCount { get; init; }
    public List<AddressCandidate> Candidates { get; init; } = new();

    /// <summary>"intelligence", "alias_correction", or "fallback_api"</summary>
    public string? Source { get; init; }

    /// <summary>"auto_resolved", "ask_which", or "airport"</summary>
    public string? DisambiguationHint { get; init; }

    /// <summary>True if any candidate is an airport.</summary>
    public bool IsAirport { get; init; }

    /// <summary>True if the airport has multiple terminals (Heathrow/Gatwick).</summary>
    public bool AskTerminal { get; init; }

    /// <summary>"Which terminal?" or "North or South terminal?"</summary>
    public string? TerminalPrompt { get; init; }
}
```

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.AI/Intelligence/Services/LocalPostcodePrefixes.cs src/backend/RedTaxi.AI/Dtos/AiToolDtos.cs
git commit -m "feat(intelligence): shared locality constants + DTO response fields"
```

---

## Task 2: IntelligenceLookup service — tests first

**Files:**
- Create: `src/backend/RedTaxi.Tests/IntelligenceLookupTests.cs`

- [ ] **Step 1: Write failing tests for IntelligenceLookup**

```csharp
// src/backend/RedTaxi.Tests/IntelligenceLookupTests.cs
using FluentAssertions;
using RedTaxi.AI.Intelligence.Services;

namespace RedTaxi.Tests;

public class IntelligenceLookupTests
{
    [Theory]
    [InlineData("airport", "AlwaysAsk")]
    [InlineData("station", "LocalDefault")]
    [InlineData("supermarket", "AlwaysAsk")]
    [InlineData("hospital", "AutoResolve")]
    [InlineData("pub", "FrequencyRank")]
    [InlineData("hotel", "FrequencyRank")]
    [InlineData("school", "AutoResolve")]
    [InlineData("residential", "FrequencyRank")]
    [InlineData("unknown", "FrequencyRank")]
    public void GetDisambiguationStrategy_ReturnsCorrectStrategy(string locationType, string expected)
    {
        IntelligenceLookup.GetDisambiguationStrategy(locationType).Should().Be(expected);
    }

    [Fact]
    public void ApplyDisambiguation_SingleResult_AutoResolves()
    {
        var candidates = new List<IntelligenceCandidate>
        {
            new() { CanonicalName = "Asda Gillingham", Postcode = "SP8 4QA", LocationType = "supermarket", Frequency = 471 }
        };
        var result = IntelligenceLookup.ApplyDisambiguation(candidates);
        result.Hint.Should().Be("auto_resolved");
        result.Candidates.Should().HaveCount(1);
    }

    [Fact]
    public void ApplyDisambiguation_MultipleSupmarkets_AsksWhich()
    {
        var candidates = new List<IntelligenceCandidate>
        {
            new() { CanonicalName = "Tesco Shaftesbury", Postcode = "SP7 8PG", LocationType = "supermarket", Frequency = 200 },
            new() { CanonicalName = "Tesco Gillingham", Postcode = "SP8 4QA", LocationType = "supermarket", Frequency = 180 },
        };
        var result = IntelligenceLookup.ApplyDisambiguation(candidates);
        result.Hint.Should().Be("ask_which");
        result.Candidates.Should().HaveCount(2);
    }

    [Fact]
    public void ApplyDisambiguation_Airport_AlwaysAsks()
    {
        var candidates = new List<IntelligenceCandidate>
        {
            new() { CanonicalName = "Bournemouth Airport", Postcode = "BH23 6SE", LocationType = "airport", Frequency = 100 }
        };
        var result = IntelligenceLookup.ApplyDisambiguation(candidates);
        result.Hint.Should().Be("airport");
        result.IsAirport.Should().BeTrue();
    }

    [Fact]
    public void ApplyDisambiguation_Station_LocalDefault()
    {
        var candidates = new List<IntelligenceCandidate>
        {
            new() { CanonicalName = "Gillingham Station", Postcode = "SP8 4PZ", LocationType = "station", Frequency = 6253 },
            new() { CanonicalName = "Tisbury Station", Postcode = "SP3 6JQ", LocationType = "station", Frequency = 80 },
        };
        var result = IntelligenceLookup.ApplyDisambiguation(candidates);
        result.Hint.Should().Be("auto_resolved");
        result.Candidates.Should().HaveCount(1);
        result.Candidates[0].CanonicalName.Should().Contain("Gillingham");
    }

    [Fact]
    public void ApplyDisambiguation_FrequencyRank_DominantAutoResolves()
    {
        var candidates = new List<IntelligenceCandidate>
        {
            new() { CanonicalName = "Royal Chase Hotel", Postcode = "SP7 8DB", LocationType = "hotel", Frequency = 300 },
            new() { CanonicalName = "Best Western", Postcode = "SP7 8JU", LocationType = "hotel", Frequency = 20 },
        };
        // 300 > 10x 20 = 200 → auto-resolve
        var result = IntelligenceLookup.ApplyDisambiguation(candidates);
        result.Hint.Should().Be("auto_resolved");
        result.Candidates[0].CanonicalName.Should().Be("Royal Chase Hotel");
    }

    [Fact]
    public void IsMultiTerminalAirport_HeathrowGatwick_True()
    {
        IntelligenceLookup.IsMultiTerminalAirport("Heathrow Airport").Should().BeTrue();
        IntelligenceLookup.IsMultiTerminalAirport("Gatwick Airport").Should().BeTrue();
    }

    [Fact]
    public void IsMultiTerminalAirport_Others_False()
    {
        IntelligenceLookup.IsMultiTerminalAirport("Bournemouth Airport").Should().BeFalse();
        IntelligenceLookup.IsMultiTerminalAirport("Bristol Airport").Should().BeFalse();
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~IntelligenceLookupTests" --no-restore`
Expected: Compilation errors — `IntelligenceLookup` class doesn't exist yet.

- [ ] **Step 3: Commit test file**

```bash
git add src/backend/RedTaxi.Tests/IntelligenceLookupTests.cs
git commit -m "test(intelligence): failing tests for IntelligenceLookup disambiguation"
```

---

## Task 3: IntelligenceLookup service — implementation

**Files:**
- Create: `src/backend/RedTaxi.AI/Intelligence/Services/IntelligenceLookup.cs`

- [ ] **Step 1: Implement IntelligenceLookup**

Create `src/backend/RedTaxi.AI/Intelligence/Services/IntelligenceLookup.cs`:

```csharp
using Microsoft.EntityFrameworkCore;
using RedTaxi.AI.Intelligence.Models;
using RedTaxi.Data;
using Serilog;

// Also uses: RedTaxi.AI.Intelligence (for IntelligenceDbContext)

namespace RedTaxi.AI.Intelligence.Services;

public record IntelligenceCandidate
{
    public int CanonicalId { get; init; }
    public string CanonicalName { get; init; } = "";
    public string SpokenName { get; init; } = "";
    public string Postcode { get; init; } = "";
    public string LocationType { get; init; } = "unknown";
    public int Frequency { get; init; }
    public double? Latitude { get; init; }
    public double? Longitude { get; init; }
}

public record DisambiguationResult(
    string Hint,               // "auto_resolved", "ask_which", "airport"
    bool IsAirport,
    bool AskTerminal,
    string? TerminalPrompt,
    List<IntelligenceCandidate> Candidates);

public record IntelligenceLookupResult(
    List<IntelligenceCandidate> Candidates,
    string Source,             // "intelligence", "alias_correction", "none"
    string? DisambiguationHint,
    bool IsAirport,
    bool AskTerminal,
    string? TerminalPrompt);

public interface IIntelligenceLookup
{
    /// <summary>
    /// Resolve a free-text query against the intelligence tables.
    /// Pass the tenant connection string (from HttpContext.Items["TenantConnectionString"]).
    /// Creates its own IntelligenceDbContext internally to access intelligence tables.
    /// </summary>
    Task<IntelligenceLookupResult> ResolveAsync(
        string query, string tenantConnectionString, CancellationToken ct);
}

public class IntelligenceLookup : IIntelligenceLookup
{
    private static readonly ILogger _log = Log.ForContext<IntelligenceLookup>();

    private static readonly HashSet<string> MultiTerminalAirports =
        new(StringComparer.OrdinalIgnoreCase) { "Heathrow", "Gatwick" };

    private static readonly Dictionary<string, string> DisambiguationStrategies = new(StringComparer.OrdinalIgnoreCase)
    {
        ["airport"] = "AlwaysAsk",
        ["station"] = "LocalDefault",
        ["supermarket"] = "AlwaysAsk",
        ["hospital"] = "AutoResolve",
        ["pub"] = "FrequencyRank",
        ["hotel"] = "FrequencyRank",
        ["school"] = "AutoResolve",
    };

    public async Task<IntelligenceLookupResult> ResolveAsync(
        string query, string tenantConnectionString, CancellationToken ct)
    {
        var normalised = AddressNormalizer.Normalize(query);
        if (normalised.Length < 2 || string.IsNullOrEmpty(tenantConnectionString))
            return Empty();

        try
        {
            // Create IntelligenceDbContext (knows about intelligence tables)
            var optBuilder = new DbContextOptionsBuilder<AppDbContext>();
            optBuilder.UseNpgsql(tenantConnectionString);
            await using var db = new IntelligenceDbContext(optBuilder.Options);

            // 1. Search canonical locations
            var canonicalHits = await db.Set<CanonicalLocation>()
                .Where(c => c.CanonicalName.ToLower().Contains(normalised))
                .OrderByDescending(c => c.TotalFrequency)
                .Take(5)
                .Select(c => new IntelligenceCandidate
                {
                    CanonicalId = c.Id,
                    CanonicalName = c.CanonicalName,
                    SpokenName = c.SpokenName,
                    Postcode = c.Postcode,
                    LocationType = c.LocationType,
                    Frequency = c.TotalFrequency,
                    Latitude = c.Latitude,
                    Longitude = c.Longitude
                })
                .ToListAsync(ct);

            // 2. Search aliases (filter nulls before Take for server-side execution)
            var aliasHits = await db.Set<LocationAlias>()
                .Include(a => a.CanonicalLocation)
                .Where(a => a.NormalisedText.Contains(normalised) && a.CanonicalLocation != null)
                .OrderByDescending(a => a.Frequency)
                .Take(5)
                .Select(a => new IntelligenceCandidate
                {
                    CanonicalId = a.CanonicalLocation!.Id,
                    CanonicalName = a.CanonicalLocation.CanonicalName,
                    SpokenName = a.CanonicalLocation.SpokenName,
                    Postcode = a.CanonicalLocation.Postcode,
                    LocationType = a.CanonicalLocation.LocationType,
                    Frequency = a.CanonicalLocation.TotalFrequency,
                    Latitude = a.CanonicalLocation.Latitude,
                    Longitude = a.CanonicalLocation.Longitude
                })
                .ToListAsync(ct);

            // 3. Merge and deduplicate by canonical ID
            var merged = canonicalHits
                .Concat(aliasHits)
                .GroupBy(c => c.CanonicalId)
                .Select(g => g.OrderByDescending(c => c.Frequency).First())
                .OrderByDescending(c => c.Frequency)
                .Take(5)
                .ToList();

            if (merged.Count == 0)
            {
                _log.Information("Intelligence MISS for '{Query}'", query);
                return Empty();
            }

            var source = canonicalHits.Count > 0 ? "intelligence" : "alias_correction";
            _log.Information("Intelligence {Source} for '{Query}' — {Count} candidates (top: {Top}, freq: {Freq})",
                source, query, merged.Count, merged[0].CanonicalName, merged[0].Frequency);

            var disambiguation = ApplyDisambiguation(merged);

            return new IntelligenceLookupResult(
                disambiguation.Candidates,
                source,
                disambiguation.Hint,
                disambiguation.IsAirport,
                disambiguation.AskTerminal,
                disambiguation.TerminalPrompt);
        }
        catch (Exception ex)
        {
            _log.Warning(ex, "Intelligence lookup failed for '{Query}' — falling back to external API", query);
            return Empty();
        }
    }

    public static string GetDisambiguationStrategy(string locationType) =>
        DisambiguationStrategies.TryGetValue(locationType, out var strategy) ? strategy : "FrequencyRank";

    public static DisambiguationResult ApplyDisambiguation(List<IntelligenceCandidate> candidates)
    {
        if (candidates.Count == 0)
            return new("auto_resolved", false, false, null, candidates);

        var topType = candidates[0].LocationType;
        var strategy = GetDisambiguationStrategy(topType);

        // Airport: always ask + terminal/bags
        if (strategy == "AlwaysAsk" && topType == "airport")
        {
            var isMulti = IsMultiTerminalAirport(candidates[0].CanonicalName);
            return new("airport", true, isMulti,
                isMulti ? GetTerminalPrompt(candidates[0].CanonicalName) : null,
                candidates);
        }

        // Single candidate: always auto-resolve
        if (candidates.Count == 1)
            return new("auto_resolved", false, false, null, candidates);

        // Apply strategy
        return strategy switch
        {
            "AlwaysAsk" => new("ask_which", false, false, null, candidates.Take(3).ToList()),

            "LocalDefault" =>
                // Pick the local candidate if one exists
                candidates.FirstOrDefault(c => LocalPostcodePrefixes.IsLocal(c.Postcode)) is { } local
                    ? new("auto_resolved", false, false, null, new List<IntelligenceCandidate> { local })
                    : new("ask_which", false, false, null, candidates.Take(3).ToList()),

            "AutoResolve" => new("auto_resolved", false, false, null,
                new List<IntelligenceCandidate> { candidates[0] }),

            "FrequencyRank" =>
                // Auto-resolve if top is 3x+ more frequent than second
                candidates[0].Frequency > candidates[1].Frequency * 3
                    ? new("auto_resolved", false, false, null, new List<IntelligenceCandidate> { candidates[0] })
                    : new("ask_which", false, false, null, candidates.Take(3).ToList()),

            _ => new("ask_which", false, false, null, candidates.Take(3).ToList()),
        };
    }

    public static bool IsMultiTerminalAirport(string name) =>
        MultiTerminalAirports.Any(a => name.Contains(a, StringComparison.OrdinalIgnoreCase));

    public static string? GetTerminalPrompt(string name)
    {
        if (name.Contains("Heathrow", StringComparison.OrdinalIgnoreCase)) return "Which terminal?";
        if (name.Contains("Gatwick", StringComparison.OrdinalIgnoreCase)) return "North or South terminal?";
        return null;
    }

    private static IntelligenceLookupResult Empty() =>
        new(new List<IntelligenceCandidate>(), "none", null, false, false, null);
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~IntelligenceLookupTests" --no-restore`
Expected: All 8 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.AI/Intelligence/Services/IntelligenceLookup.cs
git commit -m "feat(intelligence): IntelligenceLookup service with disambiguation rules"
```

---

## Task 4: Wire IntelligenceLookup into AiAgentController

**Files:**
- Modify: `src/backend/RedTaxi.AI/Controllers/AiAgentController.cs:54-81` (constructor + fields)
- Modify: `src/backend/RedTaxi.AI/Controllers/AiAgentController.cs:410-560` (LookupAddressTool)
- Modify: `src/backend/RedTaxi.API/Program.cs` (DI registration)

- [ ] **Step 1: Add IIntelligenceLookup to the controller constructor**

In `AiAgentController.cs`, add field and constructor parameter:

```csharp
// Add field (after line 60):
private readonly IIntelligenceLookup _intelligence;

// Add constructor parameter (after idempotency):
IIntelligenceLookup intelligence

// Add assignment in constructor body:
_intelligence = intelligence;
```

Also add the using: `using RedTaxi.AI.Intelligence.Services;`

- [ ] **Step 2: Rewrite LookupAddressTool to use IntelligenceLookup first**

After mishearing correction and before the existing DispatchSearch call, add the intelligence fast path:

```csharp
// ── FAST PATH: Intelligence lookup ──
var connStr = HttpContext.Items["TenantConnectionString"] as string;
if (!string.IsNullOrEmpty(connStr))
{
    var intelligenceResult = await _intelligence.ResolveAsync(query, connStr, ct);
    if (intelligenceResult.Candidates.Count > 0)
    {
        log.Information("Intelligence {Source} for '{Query}' — {Count} candidates",
            intelligenceResult.Source, query, intelligenceResult.Candidates.Count);

        var candidates = intelligenceResult.Candidates.Select(c => new AddressCandidate
        {
            Label = c.CanonicalName,
            FormattedAddress = c.CanonicalName,
            Postcode = c.Postcode,
            Spoken = !string.IsNullOrEmpty(c.SpokenName) ? c.SpokenName : c.CanonicalName,
            PostcodeSpoken = _speech.Postcode.ToSpoken(c.Postcode)
        }).ToList();

        return Ok(new LookupAddressToolResponse
        {
            CandidateCount = candidates.Count,
            Candidates = candidates,
            Source = intelligenceResult.Source,
            DisambiguationHint = intelligenceResult.DisambiguationHint,
            IsAirport = intelligenceResult.IsAirport,
            AskTerminal = intelligenceResult.AskTerminal,
            TerminalPrompt = intelligenceResult.TerminalPrompt
        });
    }
}

log.Information("Intelligence MISS for '{Query}' — falling through to DispatchSearch", query);
// ... existing DispatchSearch code continues unchanged below ...
```

This goes right after the mishearing corrector block (after line ~448) and before the `var sessionToken = ...` line.

- [ ] **Step 3: Register IIntelligenceLookup in Program.cs**

Add after the other intelligence registrations:

```csharp
builder.Services.AddSingleton<RedTaxi.AI.Intelligence.Services.IIntelligenceLookup,
    RedTaxi.AI.Intelligence.Services.IntelligenceLookup>();
```

- [ ] **Step 4: Build and verify no compilation errors**

Run: `cd src/backend && dotnet build RedTaxi.AI/RedTaxi.AI.csproj --no-restore`
Expected: Build succeeded, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add src/backend/RedTaxi.AI/Controllers/AiAgentController.cs src/backend/RedTaxi.API/Program.cs
git commit -m "feat(intelligence): wire IntelligenceLookup into lookup_address tool"
```

---

## Task 5: Route-based cached pricing in QuoteTool

**Files:**
- Modify: `src/backend/RedTaxi.AI/Controllers/AiAgentController.cs:234-299` (QuoteTool)

- [ ] **Step 1: Add route cache check before live pricing**

In `QuoteTool`, after tenant scope validation and before the `GetCashPrice` call, add:

```csharp
// Route cache fast path — check intelligence_popular_routes
try
{
    var connStr = HttpContext.Items["TenantConnectionString"] as string;
    if (!string.IsNullOrEmpty(connStr))
    {
        var optBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optBuilder.UseNpgsql(connStr);
        await using var idb = new IntelligenceDbContext(optBuilder.Options);

        var pickupNorm = AddressNormalizer.Normalize(body.PickupPostcode);
        var destNorm = AddressNormalizer.Normalize(body.DestinationPostcode);

        var cachedRoute = await idb.Set<PopularRoute>()
            .Include(r => r.PickupLocation)
            .Include(r => r.DestinationLocation)
            .Where(r => r.PickupLocation!.Postcode == body.PickupPostcode.Trim().ToUpper()
                     && r.DestinationLocation!.Postcode == body.DestinationPostcode.Trim().ToUpper()
                     && r.UsageCount > 5
                     && r.LastUsed > DateTime.UtcNow.AddDays(-90))
            .OrderByDescending(r => r.UsageCount)
            .FirstOrDefaultAsync(ct);

        if (cachedRoute != null)
        {
            log.Information("Route cache HIT: {Pickup}->{Dest} = {Fare} (usage: {Count})",
                body.PickupPostcode, body.DestinationPostcode, cachedRoute.AverageFare, cachedRoute.UsageCount);

            return Ok(new QuoteToolResponse
            {
                PriceGbp = Math.Round(cachedRoute.AverageFare, 2),
                PriceSpoken = _speech.Currency.ToSpoken(cachedRoute.AverageFare),
                TariffName = "cached estimate",
                DurationMinutes = 15, // default, will be refined by live quote if caller books
                DurationSpoken = _speech.DurationSpoken(15),
                DistanceMiles = 0
            });
        }
    }
}
catch (Exception ex)
{
    log.Warning(ex, "Route cache lookup failed — falling through to live pricing");
}
```

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.AI/RedTaxi.AI.csproj --no-restore`

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.AI/Controllers/AiAgentController.cs
git commit -m "feat(intelligence): route-based cached pricing in QuoteTool"
```

---

## Task 6: ASR keyword refresh job

**Files:**
- Create: `src/backend/RedTaxi.AI/Intelligence/Jobs/AsrKeywordRefreshJob.cs`
- Create: `src/backend/RedTaxi.Tests/AsrKeywordRefreshTests.cs`

- [ ] **Step 1: Write failing tests**

```csharp
// src/backend/RedTaxi.Tests/AsrKeywordRefreshTests.cs
using FluentAssertions;
using RedTaxi.AI.Intelligence.Jobs;

namespace RedTaxi.Tests;

public class AsrKeywordRefreshTests
{
    [Fact]
    public void MergeKeywords_DeduplicatesAndSorts()
    {
        var sttTerms = new List<(string Term, double Weight)>
        {
            ("Gillingham", 1.0),
            ("Shaftesbury", 0.5),
            ("gillingham", 0.8), // duplicate, different case
        };
        var staticTerms = new[] { "ASAP", "Terminal 5" };

        var result = AsrKeywordRefreshJob.MergeKeywords(sttTerms, staticTerms, maxKeywords: 100);

        result.Should().Contain("Gillingham"); // highest weight wins
        result.Should().Contain("Shaftesbury");
        result.Should().Contain("ASAP");
        result.Should().Contain("Terminal 5");
        result.Where(k => k.Equals("Gillingham", StringComparison.OrdinalIgnoreCase)).Should().HaveCount(1);
    }

    [Fact]
    public void MergeKeywords_RespectsMaxLimit()
    {
        var sttTerms = Enumerable.Range(1, 1000)
            .Select(i => ($"Term{i}", 1.0 / i))
            .ToList();
        var result = AsrKeywordRefreshJob.MergeKeywords(sttTerms, Array.Empty<string>(), maxKeywords: 500);
        result.Should().HaveCountLessOrEqualTo(500);
    }
}
```

- [ ] **Step 2: Implement AsrKeywordRefreshJob**

```csharp
// src/backend/RedTaxi.AI/Intelligence/Jobs/AsrKeywordRefreshJob.cs
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using RedTaxi.AI.Intelligence.Models;
using RedTaxi.Data;
using Serilog;

namespace RedTaxi.AI.Intelligence.Jobs;

public static class AsrKeywordRefreshJob
{
    private static readonly ILogger _log = Log.ForContext(typeof(AsrKeywordRefreshJob));

    // Essential terms that must always be in the ASR keyword list
    private static readonly string[] StaticKeywords =
    {
        "ASAP", "straight away", "now", "later", "tomorrow",
        "Terminal 1", "Terminal 2", "Terminal 3", "Terminal 4", "Terminal 5",
        "North Terminal", "South Terminal",
        "bags", "luggage", "suitcase", "suitcases",
        "cab", "taxi", "car",
        "half past", "quarter to", "quarter past", "o'clock",
        "Ace Taxis"
    };

    /// <summary>
    /// Generate a merged, deduplicated ASR keyword list from STT bias terms
    /// and static essential terms.
    /// </summary>
    public static List<string> MergeKeywords(
        List<(string Term, double Weight)> sttTerms,
        IEnumerable<string> staticTerms,
        int maxKeywords = 600)
    {
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var result = new List<string>();

        // Static terms first (always included)
        foreach (var term in staticTerms)
        {
            if (seen.Add(term))
                result.Add(term);
        }

        // STT terms sorted by weight descending
        foreach (var (term, _) in sttTerms.OrderByDescending(t => t.Weight))
        {
            if (result.Count >= maxKeywords) break;
            if (term.Length < 3) continue; // skip very short terms
            if (seen.Add(term))
                result.Add(term);
        }

        return result;
    }

    /// <summary>
    /// Read STT bias terms from DB and write generated-keywords.json.
    /// </summary>
    public static async Task RunAsync(RedTaxiDbContext db, string outputPath, CancellationToken ct)
    {
        var terms = await db.Set<SpeechBiasTerm>()
            .OrderByDescending(t => t.Weight)
            .Select(t => new { t.Term, t.Weight })
            .Take(800)
            .ToListAsync(ct);

        var sttTerms = terms.Select(t => (t.Term, t.Weight)).ToList();
        var merged = MergeKeywords(sttTerms, StaticKeywords);

        var dir = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        var json = JsonSerializer.Serialize(merged, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(outputPath, json, ct);

        _log.Information("ASR keywords refreshed: {Count} terms written to {Path}", merged.Count, outputPath);
    }
}
```

- [ ] **Step 3: Run tests**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~AsrKeywordRefresh" --no-restore`
Expected: 2 tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/backend/RedTaxi.AI/Intelligence/Jobs/AsrKeywordRefreshJob.cs src/backend/RedTaxi.Tests/AsrKeywordRefreshTests.cs
git commit -m "feat(intelligence): ASR keyword refresh job — data-driven STT bias"
```

---

## Task 7: System prompt updates

**Files:**
- Modify: `src/backend/RedTaxi.AI/tuning/agent-config/system-prompt.md`

- [ ] **Step 1: Add disambiguation handling section**

After the "Handling mishearings" section, add:

```markdown
## Address disambiguation

When lookup_address returns results:
- If `disambiguationHint` is `"auto_resolved"`: use the single candidate without asking. The system already picked the best match.
- If `disambiguationHint` is `"ask_which"`: present the candidates using their `spoken` labels and ask the caller to choose. Example: "Do you mean Tesco in Shaftesbury, or the one in Gillingham?"
- If `disambiguationHint` is `"airport"`: follow the airport flow below.
- If `source` is `"intelligence"` or `"alias_correction"`, the result came from booking history — it is very likely correct.
- If `source` is `"fallback_api"`, the result came from an external address service — confirm with the caller.

## Airport bookings

When lookup_address returns `isAirport: true`:
1. Always confirm which airport — "Which airport are you heading to?"
2. If `askTerminal` is true, ask using the `terminalPrompt` text (e.g. "Which terminal?" for Heathrow, "North or South terminal?" for Gatwick). For all other airports: skip the terminal question.
3. Always ask "How many bags will you have?" for any airport journey.
4. Store terminal and bags in the booking details field.

## Time-aware context

When a booking is for a station between 06:00-09:00 or 16:00-19:00, the caller is likely a commuter — keep it brisk, skip small talk.

When a booking is for a pub or restaurant after 21:00, the caller may have been drinking — be patient and clear.

When a booking is for an airport, always ask about early check-in times and whether they need a return journey.
```

- [ ] **Step 2: Commit**

```bash
git add src/backend/RedTaxi.AI/tuning/agent-config/system-prompt.md
git commit -m "feat(intelligence): system prompt — disambiguation, airports, time-aware context"
```

---

## Task 8: Sync script update for dynamic keywords

**Files:**
- Modify: `src/backend/RedTaxi.AI/tuning/sync_agent.py`

- [ ] **Step 1: Add keyword merge to sync_agent.py**

After the existing agent config is loaded but before it's pushed to ElevenLabs, add:

```python
# Merge generated keywords if the file exists
generated_keywords_path = os.path.join(AGENT_CONFIG_DIR, "generated-keywords.json")
if os.path.exists(generated_keywords_path):
    with open(generated_keywords_path, "r") as f:
        generated = json.load(f)
    if isinstance(generated, list) and len(generated) > 0:
        agent_config["conversation_config"]["asr"]["keywords"] = generated
        print(f"  Merged {len(generated)} generated ASR keywords")
```

- [ ] **Step 2: Commit**

```bash
git add src/backend/RedTaxi.AI/tuning/sync_agent.py
git commit -m "feat(intelligence): sync script merges generated ASR keywords"
```

---

## Task 9: Integration test — full flow against real DB

**Files:**
- Create: `src/backend/RedTaxi.Tests/IntelligenceLookupIntegrationTest.cs`

- [ ] **Step 1: Write integration test**

```csharp
using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using RedTaxi.AI.Intelligence;
using RedTaxi.AI.Intelligence.Services;
using RedTaxi.Data;

namespace RedTaxi.Tests;

public class IntelligenceLookupIntegrationTest
{
    [Fact]
    public async Task ResolveAsync_Asda_ReturnsLocalResult()
    {
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
        var connStr = "Host=localhost;Port=5432;Database=redtaxi;Username=postgres;Password=postgres";
        var opts = new DbContextOptionsBuilder<AppDbContext>();
        opts.UseNpgsql(connStr);
        await using var db = new IntelligenceDbContext(opts.Options);

        var lookup = new IntelligenceLookup();
        var result = await lookup.ResolveAsync("asda", db, CancellationToken.None);

        result.Source.Should().NotBe("none", "Asda should exist in the intelligence data");
        result.Candidates.Should().NotBeEmpty();
        result.Candidates[0].Postcode.Should().StartWith("SP", "Should return local Asda");
    }

    [Fact]
    public async Task ResolveAsync_Station_DefaultsToGillingham()
    {
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
        var connStr = "Host=localhost;Port=5432;Database=redtaxi;Username=postgres;Password=postgres";
        var opts = new DbContextOptionsBuilder<AppDbContext>();
        opts.UseNpgsql(connStr);
        await using var db = new IntelligenceDbContext(opts.Options);

        var lookup = new IntelligenceLookup();
        var result = await lookup.ResolveAsync("station", db, CancellationToken.None);

        result.Source.Should().NotBe("none");
        result.DisambiguationHint.Should().Be("auto_resolved");
        result.Candidates.Should().HaveCount(1);
        result.Candidates[0].CanonicalName.Should().Contain("gillingham", StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ResolveAsync_Tesco_AskWhich()
    {
        AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
        var connStr = "Host=localhost;Port=5432;Database=redtaxi;Username=postgres;Password=postgres";
        var opts = new DbContextOptionsBuilder<AppDbContext>();
        opts.UseNpgsql(connStr);
        await using var db = new IntelligenceDbContext(opts.Options);

        var lookup = new IntelligenceLookup();
        var result = await lookup.ResolveAsync("tesco", db, CancellationToken.None);

        result.Source.Should().NotBe("none");
        // Multiple Tescos should trigger ask_which (supermarket = AlwaysAsk)
        if (result.Candidates.Count > 1)
            result.DisambiguationHint.Should().Be("ask_which");
    }
}
```

- [ ] **Step 2: Run integration tests**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~IntelligenceLookupIntegration" --no-restore`
Expected: All 3 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Tests/IntelligenceLookupIntegrationTest.cs
git commit -m "test(intelligence): integration tests — Asda local, station default, Tesco disambiguation"
```

---

## Task 10: Final verification

- [ ] **Step 1: Run ALL intelligence tests**

Run: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~Intelligence" --no-restore`
Expected: All tests pass (unit + integration).

- [ ] **Step 2: Run the full backfill + ASR keyword refresh**

Run the backfill test: `cd src/backend && dotnet test RedTaxi.Tests --filter "FullyQualifiedName~RunFullBackfill" --no-restore`
Expected: PASS (pipeline runs, exports generated, intelligence tables populated).

- [ ] **Step 3: Final commit with all files**

```bash
git add -A
git commit -m "feat(intelligence): complete intelligence-powered voice agent — all layers wired"
```
