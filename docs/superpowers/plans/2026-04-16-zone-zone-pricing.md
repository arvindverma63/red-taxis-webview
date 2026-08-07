# Zone-to-Zone Pricing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build zone-to-zone polygon pricing as a new tariff mode that slots alongside the existing mileage engine. Ship in two PRs: PR1 = admin CRUD + standalone quote endpoint; PR2 = dispatch + AI agent integration.

**Architecture:** New `IZonePricingResolver` called from existing pricing handlers (middleware-override pattern). Resolver uses `NetTopologySuite` for point-in-polygon / overlap / geometry math. New tables `ZonePolygons` + `ZonePriceMatrix` in tenant DB. V1 tables (`GeoFences`, `ZoneToZonePrices`) untouched. Coords come from new `Booking.{Pickup,Destination}{Lat,Lng}` columns with fallback to a `PostcodeCoordinates` cache (populated lazily via tenant's geocoder).

**Tech Stack:** .NET 8, EF Core 8, PostgreSQL (Npgsql + int[] + jsonb), NetTopologySuite, MediatR, Serilog, Next.js 16, React 19, TanStack Query v5, `@vis.gl/react-google-maps`, Google Maps Drawing Library, shadcn/ui, Verify snapshot tests, WebApplicationFactory integration tests.

**Spec:** `docs/superpowers/specs/2026-04-16-zone-zone-pricing-design.md`

**Branch:** `feature/zone-zone-pricing` (already created and pushed)

---

## File Structure

### Backend — new files (under `src/backend/`)

**Domain & Data**
- `RedTaxi.Data/Models/ZonePolygon.cs` — entity
- `RedTaxi.Data/Models/ZonePriceMatrix.cs` — entity
- `RedTaxi.Data/Models/PostcodeCoordinate.cs` — entity (cache)
- `RedTaxi.Data/Migrations/<ts>_AddZonePricingTables.cs` — EF migration

**Application — ZonePricing feature slice (`RedTaxi.Application/Features/ZonePricing/`)**
- `Internal/IZoneGeometryService.cs` + `ZoneGeometryService.cs` — NetTopologySuite wrapper (point-in-polygon, overlap, area, centroid, is-valid)
- `Internal/IZonePricingResolver.cs` + `ZonePricingResolver.cs` — the resolver
- `Internal/ZoneCacheInvalidator.cs` — per-tenant cache
- `Internal/IPostcodeGeocoder.cs` + `PostcodeGeocoder.cs` — geocoding + cache write-through
- `Internal/ZoneCsvParser.cs` — CSV import/export
- `Internal/ZoneMatrixExportCsv.cs` — CSV writer
- `Zones/CreateZone.cs`, `UpdateZone.cs`, `DeleteZone.cs`, `ListZones.cs`, `GetZone.cs`, `ValidateZone.cs`
- `Matrix/ListMatrix.cs`, `UpsertMatrix.cs`, `DeleteMatrixRow.cs`, `ExportMatrix.cs`, `ImportMatrix.cs`
- `Quote/GetZoneQuote.cs`
- `Shared/ZoneDtos.cs` — request/response records

**API (`RedTaxi.API/`)**
- `Controllers/V2/ZonePricingController.cs` — routing-only

**Tests (`RedTaxi.Tests/`)**
- `SnapshotTests/ZonePricingSnapshotTests.cs` — Verify tests (12+ scenarios)
- `UnitTests/ZoneGeometryServiceTests.cs`
- `UnitTests/ZonePricingResolverTests.cs`

### Backend — modified files

- `RedTaxi.API/RedTaxi.API.csproj` — add `NetTopologySuite` package ref
- `RedTaxi.Data/RedTaxi.Data.csproj` — add `NetTopologySuite` package ref
- `RedTaxi.Data/RedTaxiDbContext.cs` — add 3 DbSets + model config
- `RedTaxi.Data/Models/Booking.cs` — add 4 coord columns + `PriceSource`
- `RedTaxi.API/Program.cs` — DI registrations (4 lines)
- `RedTaxi.Shared/Extensions/ServiceCollectionExtensions.cs` (if exists; else `Program.cs`) — DI
- **PR2 only:**
  - `RedTaxi.Application/Features/Bookings/CreateBooking.cs` — inject resolver
  - `RedTaxi.Application/Features/Pricing/GetCashPrice.cs` — inject resolver + extend response
  - `RedTaxi.Application/Features/WebBookings/GetDuration.cs` — inject resolver
  - `RedTaxi.AI/Intelligence/Services/IntelligenceCache.cs` — wrap route pricing

### Frontend admin-v2 — new files (`src/frontend/apps/admin-v2/src/`)

**Pages**
- `app/(dashboard)/settings/zone-pricing/zones/page.tsx`
- `app/(dashboard)/settings/zone-pricing/matrix/page.tsx`

**Components (`components/admin/zone-editor/`)**
- `ZoneMap.tsx` — map + drawing manager
- `ZoneSidebar.tsx` — zone list
- `ZoneSaveDialog.tsx`
- `ZoneDeleteDialog.tsx`
- `MatrixGrid.tsx`
- `PricingSettingsCard.tsx`
- `MatrixCsvImportDialog.tsx`
- `PriceSourceChip.tsx` — shared chip (PR2)
- `snap-helpers.ts` — pure snap math
- `geometry-helpers.ts` — client-side overlap/self-intersection preview (server always revalidates)

**Hooks (`lib/hooks/`)**
- `use-zones.ts`
- `use-zone-matrix.ts`
- `use-zone-quote.ts`

**Nav**
- `lib/navigation.ts` — add Zone Pricing entries

### Frontend headless-dispatch — modified files (PR2 only)

- `src/components/BookingForm/QuoteDialog.jsx` — render `PriceSourceChip`
- `src/pages/Booking.jsx` — wherever the inline price chip sits — render `PriceSourceChip`
- `src/api/apiReq.js` (or equivalent) — extend `getPrice` to pass lat/lng + receive `zone` payload

---

## Phase 1 — PR1 (admin CRUD + standalone quote endpoint)

### Task 1: Branch + baseline

**Files:** `feature/zone-zone-pricing` (already exists)

- [ ] **Step 1: Confirm on correct branch**

```bash
cd o:/RedTaxi
git status
git branch --show-current
```
Expected: `feature/zone-zone-pricing`, clean working tree (one untracked log file is OK).

- [ ] **Step 2: Confirm staging API is healthy**

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://staging-api.redtaxi.co.uk/health
```
Expected: `200`

---

### Task 2: Add NetTopologySuite package + entities

**Files:**
- Modify: `src/backend/RedTaxi.Data/RedTaxi.Data.csproj`
- Modify: `src/backend/RedTaxi.API/RedTaxi.API.csproj`
- Create: `src/backend/RedTaxi.Data/Models/ZonePolygon.cs`
- Create: `src/backend/RedTaxi.Data/Models/ZonePriceMatrix.cs`
- Create: `src/backend/RedTaxi.Data/Models/PostcodeCoordinate.cs`
- Modify: `src/backend/RedTaxi.Data/Models/Booking.cs`

- [ ] **Step 1: Add NetTopologySuite package to Data + API projects**

Edit both `.csproj` files. Add:
```xml
<PackageReference Include="NetTopologySuite" Version="2.5.0" />
```
Do NOT add `Microsoft.EntityFrameworkCore.SqlServer.NetTopologySuite` or `Npgsql.EntityFrameworkCore.PostgreSQL.NetTopologySuite` — we persist polygons as jsonb, not as Postgres geometry columns, to keep the schema PostGIS-free (per spec §3).

- [ ] **Step 2: Create `ZonePolygon.cs`**

```csharp
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RedTaxi.Data.Models;

public class ZonePolygon
{
    [Key] public int Id { get; set; }

    [Required, MaxLength(100)] public string Name { get; set; } = default!;

    /// <summary>JSON array of {lat,lng} — open polygon (last point != first).</summary>
    [Column(TypeName = "jsonb")]
    public string PointsJson { get; set; } = "[]";

    [Column(TypeName = "numeric(9,7)")] public decimal CentroidLat { get; set; }
    [Column(TypeName = "numeric(10,7)")] public decimal CentroidLng { get; set; }
    [Column(TypeName = "numeric(10,4)")] public decimal AreaKm2 { get; set; }

    [Column(TypeName = "numeric(9,7)")] public decimal BoundingMinLat { get; set; }
    [Column(TypeName = "numeric(9,7)")] public decimal BoundingMaxLat { get; set; }
    [Column(TypeName = "numeric(10,7)")] public decimal BoundingMinLng { get; set; }
    [Column(TypeName = "numeric(10,7)")] public decimal BoundingMaxLng { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
```

- [ ] **Step 3: Create `ZonePriceMatrix.cs`**

```csharp
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RedTaxi.Data.Models;

public class ZonePriceMatrix
{
    [Key] public int Id { get; set; }

    public int FromZoneId { get; set; }
    public int ToZoneId { get; set; }

    /// <summary>NULL = default. [9999] = cash-only. Array of account numbers.</summary>
    public int[]? AccountNumbers { get; set; }

    [Column(TypeName = "numeric(10,2)")] public decimal Tariff1Cost { get; set; }
    [Column(TypeName = "numeric(10,2)")] public decimal Tariff1Price { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(FromZoneId))] public virtual ZonePolygon? FromZone { get; set; }
    [ForeignKey(nameof(ToZoneId))] public virtual ZonePolygon? ToZone { get; set; }
}
```

- [ ] **Step 4: Create `PostcodeCoordinate.cs`**

```csharp
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace RedTaxi.Data.Models;

public class PostcodeCoordinate
{
    [Key] public int Id { get; set; }

    [Required, MaxLength(10)] public string Postcode { get; set; } = default!;
    [Column(TypeName = "numeric(9,7)")] public decimal Latitude { get; set; }
    [Column(TypeName = "numeric(10,7)")] public decimal Longitude { get; set; }
    [Required, MaxLength(20)] public string Source { get; set; } = "google";
    public DateTime CachedAt { get; set; } = DateTime.UtcNow;
}
```

- [ ] **Step 5: Add coord columns to `Booking.cs`**

Append nullable properties (do not touch existing fields):
```csharp
[Column(TypeName = "numeric(9,7)")]  public decimal? PickupLat { get; set; }
[Column(TypeName = "numeric(10,7)")] public decimal? PickupLng { get; set; }
[Column(TypeName = "numeric(9,7)")]  public decimal? DestinationLat { get; set; }
[Column(TypeName = "numeric(10,7)")] public decimal? DestinationLng { get; set; }
[MaxLength(10)] public string PriceSource { get; set; } = "mileage";
```

- [ ] **Step 6: Build and verify**

```bash
cd src/backend && dotnet build RedTaxi.API/RedTaxi.API.csproj -c Debug --nologo -v minimal 2>&1 | tail -10
```
Expected: `0 Error(s)`.

- [ ] **Step 7: Commit**

```bash
git add src/backend/
git commit -m "feat(zone-pricing): add entity models + NetTopologySuite package"
```

---

### Task 3: DbContext registration + EF migration

**Files:**
- Modify: `src/backend/RedTaxi.Data/RedTaxiDbContext.cs`
- Create: `src/backend/RedTaxi.Data/Migrations/<ts>_AddZonePricingTables.cs` (via EF tools)

- [ ] **Step 1: Register DbSets + configure in `RedTaxiDbContext.cs`**

Add to the DbSet section:
```csharp
public virtual DbSet<ZonePolygon> ZonePolygons { get; set; } = null!;
public virtual DbSet<ZonePriceMatrix> ZonePriceMatrix { get; set; } = null!;
public virtual DbSet<PostcodeCoordinate> PostcodeCoordinates { get; set; } = null!;
```

Add to `OnModelCreating`:
```csharp
modelBuilder.Entity<ZonePolygon>(b =>
{
    b.HasIndex(x => x.IsActive);
    b.HasIndex(x => x.Name)
     .IsUnique()
     .HasFilter("\"IsActive\" = true");
});

modelBuilder.Entity<ZonePriceMatrix>(b =>
{
    b.HasOne(x => x.FromZone).WithMany().HasForeignKey(x => x.FromZoneId).OnDelete(DeleteBehavior.Restrict);
    b.HasOne(x => x.ToZone).WithMany().HasForeignKey(x => x.ToZoneId).OnDelete(DeleteBehavior.Restrict);
    b.HasIndex(x => new { x.FromZoneId, x.ToZoneId, x.IsActive });
    b.HasIndex(x => x.AccountNumbers).HasMethod("gin");
    b.ToTable(t => t.HasCheckConstraint("CK_ZonePriceMatrix_NoDiagonal", "\"FromZoneId\" <> \"ToZoneId\""));
    b.HasIndex(x => new { x.FromZoneId, x.ToZoneId })
     .IsUnique()
     .HasFilter("\"AccountNumbers\" IS NULL AND \"IsActive\" = true");
});

modelBuilder.Entity<PostcodeCoordinate>(b =>
{
    b.HasIndex(x => x.Postcode).IsUnique();
});
```

- [ ] **Step 2: Generate migration**

```bash
cd src/backend/RedTaxi.Data
dotnet ef migrations add AddZonePricingTables --startup-project ../RedTaxi.API --context RedTaxiDbContext
```

- [ ] **Step 3: Review generated migration**

Open `Migrations/<ts>_AddZonePricingTables.cs`. Verify:
- Creates `ZonePolygons`, `ZonePriceMatrix`, `PostcodeCoordinates`
- Adds `PickupLat`, `PickupLng`, `DestinationLat`, `DestinationLng` (nullable), `PriceSource` (default `"mileage"`) columns to `Bookings`
- Check constraint on `ZonePriceMatrix`
- GIN index on `AccountNumbers`
- Unique partial indexes

If anything is wrong, edit the `Up()`/`Down()` methods by hand — they're plain C#.

- [ ] **Step 4: Apply to local dev DB**

```bash
cd src/backend/RedTaxi.API
dotnet ef database update --context RedTaxiDbContext
```
Expected: `Done.`

- [ ] **Step 5: Verify columns in Postgres**

```bash
PGPASSWORD=postgres "C:/Program Files/PostgreSQL/17/bin/psql.exe" -h localhost -U postgres -d redtaxi -c "\d+ \"ZonePolygons\"" | head -20
PGPASSWORD=postgres "C:/Program Files/PostgreSQL/17/bin/psql.exe" -h localhost -U postgres -d redtaxi -c "\d+ \"ZonePriceMatrix\"" | head -20
```

- [ ] **Step 6: Commit**

```bash
git add src/backend/RedTaxi.Data/
git commit -m "feat(zone-pricing): EF migration + DbContext registration"
```

---

### Task 4: Geometry service (NetTopologySuite wrapper)

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/IZoneGeometryService.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ZoneGeometryService.cs`
- Create: `src/backend/RedTaxi.Tests/UnitTests/ZoneGeometryServiceTests.cs`

- [ ] **Step 1: Write failing tests first**

```csharp
using RedTaxi.Application.Features.ZonePricing.Internal;
using Xunit;

public class ZoneGeometryServiceTests
{
    private readonly IZoneGeometryService _sut = new ZoneGeometryService();

    private static List<(double Lat, double Lng)> Square(double centerLat, double centerLng, double half)
        => new()
        {
            (centerLat - half, centerLng - half),
            (centerLat - half, centerLng + half),
            (centerLat + half, centerLng + half),
            (centerLat + half, centerLng - half),
        };

    [Fact]
    public void ContainsPoint_InsideSimpleSquare_True()
    {
        var result = _sut.ContainsPoint(Square(51, -2, 0.01), 51, -2);
        Assert.True(result);
    }

    [Fact]
    public void ContainsPoint_OutsideSquare_False()
    {
        var result = _sut.ContainsPoint(Square(51, -2, 0.01), 52, -2);
        Assert.False(result);
    }

    [Fact]
    public void ContainsPoint_OnEdge_True()
    {
        // Point exactly on the west edge
        var result = _sut.ContainsPoint(Square(51, -2, 0.01), 51, -2.01);
        Assert.True(result);  // we use Covers(), includes boundary
    }

    [Fact]
    public void IsSelfIntersecting_BowtiePolygon_True()
    {
        var bowtie = new List<(double,double)> { (0,0), (1,1), (1,0), (0,1) };
        Assert.True(_sut.IsSelfIntersecting(bowtie));
    }

    [Fact]
    public void IsSelfIntersecting_Square_False()
    {
        Assert.False(_sut.IsSelfIntersecting(Square(51, -2, 0.01)));
    }

    [Fact]
    public void Overlaps_TwoDisjointSquares_False()
    {
        var a = Square(51, -2, 0.01);
        var b = Square(51.1, -2, 0.01);
        Assert.False(_sut.Overlaps(a, b));
    }

    [Fact]
    public void Overlaps_OverlappingSquares_True()
    {
        var a = Square(51, -2, 0.02);
        var b = Square(51.015, -2, 0.02);
        Assert.True(_sut.Overlaps(a, b));
    }

    [Fact]
    public void Overlaps_SharedBorderOnly_False()
    {
        // Two squares touching at one edge exactly — not overlap, just adjacency
        var a = Square(51, -2, 0.01);   // east edge at -1.99
        var b = Square(51, -1.98, 0.01); // west edge at -1.99
        Assert.False(_sut.Overlaps(a, b));
    }

    [Fact]
    public void Area_UnitSquare_Approx()
    {
        // 0.01° x 0.01° at lat 51 ≈ 0.7 × 1.1 km
        var area = _sut.AreaKm2(Square(51, -2, 0.005));
        Assert.InRange(area, 0.5, 1.5);
    }

    [Fact]
    public void Centroid_Square_IsCenter()
    {
        var (lat, lng) = _sut.Centroid(Square(51.5, -2.5, 0.01));
        Assert.Equal(51.5, lat, 4);
        Assert.Equal(-2.5, lng, 4);
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
cd src/backend
dotnet test RedTaxi.Tests --filter "FullyQualifiedName~ZoneGeometryServiceTests" --nologo --no-restore 2>&1 | tail -15
```
Expected: `FAIL` — IZoneGeometryService not defined.

- [ ] **Step 3: Write `IZoneGeometryService.cs`**

```csharp
namespace RedTaxi.Application.Features.ZonePricing.Internal;

public interface IZoneGeometryService
{
    bool ContainsPoint(IReadOnlyList<(double Lat, double Lng)> polygon, double lat, double lng);
    bool IsSelfIntersecting(IReadOnlyList<(double Lat, double Lng)> polygon);
    bool Overlaps(IReadOnlyList<(double Lat, double Lng)> a, IReadOnlyList<(double Lat, double Lng)> b);
    decimal AreaKm2(IReadOnlyList<(double Lat, double Lng)> polygon);
    (double Lat, double Lng) Centroid(IReadOnlyList<(double Lat, double Lng)> polygon);
    (double MinLat, double MaxLat, double MinLng, double MaxLng) BoundingBox(IReadOnlyList<(double Lat, double Lng)> polygon);
}
```

- [ ] **Step 4: Write `ZoneGeometryService.cs`**

```csharp
using NetTopologySuite.Algorithm;
using NetTopologySuite.Geometries;
using NetTopologySuite.Operation.Valid;

namespace RedTaxi.Application.Features.ZonePricing.Internal;

public class ZoneGeometryService : IZoneGeometryService
{
    private static readonly GeometryFactory Factory = new(new PrecisionModel(), 4326);

    private static Polygon ToPolygon(IReadOnlyList<(double Lat, double Lng)> pts)
    {
        if (pts.Count < 3) throw new ArgumentException("Polygon requires >= 3 points.");

        // NTS expects ring to be closed (first == last)
        var coords = new Coordinate[pts.Count + 1];
        for (int i = 0; i < pts.Count; i++) coords[i] = new Coordinate(pts[i].Lng, pts[i].Lat);  // x=lng, y=lat
        coords[^1] = coords[0];
        return Factory.CreatePolygon(coords);
    }

    public bool ContainsPoint(IReadOnlyList<(double Lat, double Lng)> polygon, double lat, double lng)
    {
        var poly = ToPolygon(polygon);
        var pt = Factory.CreatePoint(new Coordinate(lng, lat));
        return poly.Covers(pt);  // includes boundary
    }

    public bool IsSelfIntersecting(IReadOnlyList<(double Lat, double Lng)> polygon)
    {
        var poly = ToPolygon(polygon);
        return !poly.IsValid;  // IsValid is false for self-intersecting rings
    }

    public bool Overlaps(IReadOnlyList<(double Lat, double Lng)> a, IReadOnlyList<(double Lat, double Lng)> b)
    {
        var polyA = ToPolygon(a);
        var polyB = ToPolygon(b);
        // Use Intersects + Relate to exclude touch-only (shared border)
        if (!polyA.Intersects(polyB)) return false;
        var im = polyA.Relate(polyB);
        // DE-9IM: overlap if interiors intersect
        return im.Matches("T********") || im.Matches("****T****");  // interior-interior or boundary-interior
        // simpler: return polyA.Overlaps(polyB) || polyA.Contains(polyB) || polyB.Contains(polyA);
    }

    public decimal AreaKm2(IReadOnlyList<(double Lat, double Lng)> polygon)
    {
        // Approximate area — convert degrees to km at polygon's latitude
        var poly = ToPolygon(polygon);
        var latRad = Math.PI * poly.Centroid.Y / 180.0;
        const double kmPerDegLat = 111.32;
        var kmPerDegLng = 111.32 * Math.Cos(latRad);
        var areaDeg2 = poly.Area;  // in degrees squared
        var areaKm2 = areaDeg2 * kmPerDegLat * kmPerDegLng;
        return Math.Round((decimal)areaKm2, 4);
    }

    public (double Lat, double Lng) Centroid(IReadOnlyList<(double Lat, double Lng)> polygon)
    {
        var c = ToPolygon(polygon).Centroid;
        return (c.Y, c.X);
    }

    public (double MinLat, double MaxLat, double MinLng, double MaxLng) BoundingBox(IReadOnlyList<(double Lat, double Lng)> polygon)
    {
        double minLat = double.MaxValue, maxLat = double.MinValue, minLng = double.MaxValue, maxLng = double.MinValue;
        foreach (var p in polygon)
        {
            if (p.Lat < minLat) minLat = p.Lat;
            if (p.Lat > maxLat) maxLat = p.Lat;
            if (p.Lng < minLng) minLng = p.Lng;
            if (p.Lng > maxLng) maxLng = p.Lng;
        }
        return (minLat, maxLat, minLng, maxLng);
    }
}
```

- [ ] **Step 5: Run tests, verify they pass**

```bash
cd src/backend
dotnet test RedTaxi.Tests --filter "FullyQualifiedName~ZoneGeometryServiceTests" --nologo --no-restore 2>&1 | tail -10
```
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/ZonePricing/ src/backend/RedTaxi.Tests/UnitTests/
git commit -m "feat(zone-pricing): geometry service + unit tests"
```

---

### Task 5: Zones CRUD handlers + validation

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Shared/ZoneDtos.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Zones/{Create,Update,Delete,List,Get,Validate}Zone.cs`

- [ ] **Step 1: Write DTOs (`ZoneDtos.cs`)**

```csharp
namespace RedTaxi.Application.Features.ZonePricing.Shared;

public record LatLngDto(double Lat, double Lng);

public record ZoneDto(
    int Id,
    string Name,
    List<LatLngDto> Points,
    decimal CentroidLat,
    decimal CentroidLng,
    decimal AreaKm2,
    bool IsActive,
    DateTime UpdatedAt);

public record ZoneValidationIssue(string Type, int? OtherZoneId, string? OtherZoneName);

public record ZoneValidationResult(bool Valid, List<ZoneValidationIssue> Issues);

public record MatrixCellDto(
    int Id,
    int FromZoneId,
    int ToZoneId,
    int[]? AccountNumbers,
    decimal Tariff1Cost,
    decimal Tariff1Price,
    bool IsActive);

public record MatrixDto(List<ZoneDto> Zones, List<MatrixCellDto> Cells);
```

- [ ] **Step 2: Write `CreateZone.cs`**

Standard MediatR command handler that:
1. Validates ≥ 3 points
2. Normalises name + checks uniqueness (active)
3. Calls `IZoneGeometryService.IsSelfIntersecting` → if true, return `Result.Fail("SELF_INTERSECTING")`
4. Loads all active zones, calls `Overlaps` on each → if any, return `Result.Fail("OVERLAPS", otherZoneId, otherZoneName)`
5. Computes centroid, area, bounding box
6. Serialises points to JSON
7. Inserts row, saves
8. Invalidates zone cache via `ZoneCacheInvalidator.Invalidate()`
9. Logs structured `Feature: "ZonePricing_CreateZone"`
10. Returns `ZoneDto`

Full code in spec §3-4. Follow exact pattern of existing handlers (e.g. `CreatePOI.cs`).

- [ ] **Step 3: Write `UpdateZone.cs`**

Same validation as Create, excluding the zone being updated from the overlap check.

- [ ] **Step 4: Write `DeleteZone.cs`**

Soft-delete (set `IsActive=false`). Before deletion, check for active `ZonePriceMatrix` rows referencing this zone — if any, return `Result.Fail("BLOCKED_BY_MATRIX", matrixRowIds)`.

- [ ] **Step 5: Write `ListZones.cs`**

Returns all zones (active + inactive if `?includeInactive=true`). Admin UI default: active only.

- [ ] **Step 6: Write `GetZone.cs`**

- [ ] **Step 7: Write `ValidateZone.cs`**

Same geometry checks as CreateZone but NO DB write. Used by UI for live validation.

- [ ] **Step 8: Build and verify**

```bash
cd src/backend && dotnet build --nologo -v minimal 2>&1 | tail -5
```

- [ ] **Step 9: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/ZonePricing/Zones/ src/backend/RedTaxi.Application/Features/ZonePricing/Shared/
git commit -m "feat(zone-pricing): zones CRUD handlers (create/update/delete/list/get/validate)"
```

---

### Task 6: Matrix CRUD handlers + CSV import/export

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Matrix/{ListMatrix,UpsertMatrix,DeleteMatrixRow,ExportMatrix,ImportMatrix}.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ZoneCsvParser.cs`

- [ ] **Step 1: Write `ListMatrix.cs`**

Accepts optional `accountNo` filter. Returns `MatrixDto` with zones + cells. Default filter shows cells where `AccountNumbers IS NULL OR accountNo ∈ AccountNumbers`.

- [ ] **Step 2: Write `UpsertMatrix.cs`**

Merge semantics. Accepts `List<MatrixCellDto>`. For each row in request:
- If `Id` > 0: UPDATE
- Else: INSERT
Transaction wraps the whole batch. Rows not in request are preserved.

- [ ] **Step 3: Write `DeleteMatrixRow.cs`**

Soft-delete (`IsActive=false`).

- [ ] **Step 4: Write `ZoneCsvParser.cs`**

Pure utility. Methods:
```csharp
public static string ToCsv(IEnumerable<ZonePolygon> zones, IEnumerable<ZonePriceMatrix> cells);
public static (List<MatrixCellDto> rows, List<string> errors) ParseCsv(string csv, IReadOnlyDictionary<string, int> zoneNameToId);
```

CSV format:
```
FromZone,ToZone,AccountNumbers,Tariff1Cost,Tariff1Price
Gillingham,Heathrow Airport,9999,195.00,225.00
Heathrow Airport,Gillingham,9999,210.00,245.00
Gillingham,Heathrow Airport,,180.00,210.00  # default (empty AccountNumbers)
```

- [ ] **Step 5: Write `ExportMatrix.cs`**

Returns CSV string wrapped in Result.

- [ ] **Step 6: Write `ImportMatrix.cs`**

Parses CSV, validates each row, performs upsert. Returns `{inserted, updated, errors[]}`.

- [ ] **Step 7: Build**

```bash
cd src/backend && dotnet build --nologo -v minimal 2>&1 | tail -5
```

- [ ] **Step 8: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/ZonePricing/Matrix/ src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ZoneCsvParser.cs
git commit -m "feat(zone-pricing): matrix CRUD + CSV import/export handlers"
```

---

### Task 7: Postcode geocoder + cache

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/IPostcodeGeocoder.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/PostcodeGeocoder.cs`

- [ ] **Step 1: Write interface**

```csharp
public interface IPostcodeGeocoder
{
    Task<(double Lat, double Lng)?> ResolveAsync(string postcode, CancellationToken ct);
}
```

- [ ] **Step 2: Write implementation**

```csharp
public class PostcodeGeocoder : IPostcodeGeocoder
{
    private readonly RedTaxiDbContext _db;
    private readonly IHttpClientFactory _httpFactory;
    private readonly ITenantConfigService _tenantConfig;
    private static readonly Serilog.ILogger _log = Log.ForContext<PostcodeGeocoder>();

    public async Task<(double Lat, double Lng)?> ResolveAsync(string postcode, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(postcode)) return null;
        var norm = postcode.Replace(" ", "").ToUpperInvariant();

        // 1. Cache
        var cached = await _db.PostcodeCoordinates.AsNoTracking()
            .FirstOrDefaultAsync(p => p.Postcode == norm, ct);
        if (cached != null) return ((double)cached.Latitude, (double)cached.Longitude);

        // 2. Geocode via Google (fallback provider — simplest; tenant's AddressProvider is for search, not geocoding here)
        var apiKey = await _tenantConfig.GetAsync("GoogleMapsApiKey", "");
        if (string.IsNullOrEmpty(apiKey)) return null;

        try
        {
            var http = _httpFactory.CreateClient();
            var url = $"https://maps.googleapis.com/maps/api/geocode/json?address={Uri.EscapeDataString(norm)}&region=uk&key={apiKey}";
            var resp = await http.GetFromJsonAsync<GeocodeResponse>(url, ct);
            var loc = resp?.Results?.FirstOrDefault()?.Geometry?.Location;
            if (loc == null) return null;

            // 3. Write-through cache
            _db.PostcodeCoordinates.Add(new PostcodeCoordinate
            {
                Postcode = norm,
                Latitude = (decimal)loc.Lat,
                Longitude = (decimal)loc.Lng,
                Source = "google",
            });
            await _db.SaveChangesAsync(ct);

            return (loc.Lat, loc.Lng);
        }
        catch (Exception ex)
        {
            _log.Warning(ex, "Postcode geocode failed for {Postcode}", norm);
            return null;
        }
    }

    private record GeocodeResponse(List<GeocodeResult> Results);
    private record GeocodeResult(GeocodeGeometry Geometry);
    private record GeocodeGeometry(GeocodeLocation Location);
    private record GeocodeLocation(double Lat, double Lng);
}
```

- [ ] **Step 3: Build + commit**

```bash
cd src/backend && dotnet build --nologo -v minimal 2>&1 | tail -3
git add src/backend/RedTaxi.Application/Features/ZonePricing/Internal/IPostcodeGeocoder.cs src/backend/RedTaxi.Application/Features/ZonePricing/Internal/PostcodeGeocoder.cs
git commit -m "feat(zone-pricing): postcode geocoder with write-through cache"
```

---

### Task 8: Zone cache + pricing resolver

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ZoneCacheInvalidator.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/IZonePricingResolver.cs`
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ZonePricingResolver.cs`
- Create: `src/backend/RedTaxi.Tests/UnitTests/ZonePricingResolverTests.cs`

- [ ] **Step 1: Write `ZoneCacheInvalidator.cs`**

Singleton `ConcurrentDictionary<string, List<ZonePolygonCacheEntry>>` keyed on tenant connection string. Exposes:
- `GetOrLoadAsync(connStr, loader)` — returns cached list or loads via loader
- `Invalidate(connStr)` — clears entry for a tenant

- [ ] **Step 2: Write `IZonePricingResolver.cs`** (interface per spec §4.1)

- [ ] **Step 3: Write failing resolver tests**

Test scenarios (per spec §5.5):
1. Both in zones, matrix exists → returns price
2. Same, Sunday → T2 multiplier applied
3. Same, Christmas Eve 19:00 → T3
4. Pickup outside zones → returns null
5. With on-route via → reason "zone+stop-fee"
6. With diversion via → reason "zone+detour"
7. Disabled via tenant setting → returns null
8. Resolver throws → null (silent failure)

Use in-memory DB (`UseInMemoryDatabase`) + mocked `IPostcodeGeocoder` + stubbed `ITenantConfigService` + real `ZoneGeometryService`.

- [ ] **Step 4: Run tests, verify red**

- [ ] **Step 5: Implement `ZonePricingResolver.cs`**

Follow spec §4.2–4.7 exactly. Key points:
- Early return null if `ZonePricing.Enabled != "true"`
- Resolve pickup + drop lat/lng via query fields first, then postcode, then geocoder, else null
- Use cache for zone list, bounding-box filter, then `Covers()` for point-in-polygon
- Matrix lookup: account-specific first, then default
- Apply T2/T3 multiplier
- Apply MPV surcharge if `IsLargeVehicle`
- Via pricing: one Google Distance call to get direct miles, one to get via miles
- All exceptions caught → log Error → return null

- [ ] **Step 6: Run tests, verify green**

- [ ] **Step 7: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/ZonePricing/Internal/ src/backend/RedTaxi.Tests/UnitTests/ZonePricingResolverTests.cs
git commit -m "feat(zone-pricing): resolver + in-memory tenant zone cache"
```

---

### Task 9: Quote endpoint handler

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/ZonePricing/Quote/GetZoneQuote.cs`

- [ ] **Step 1: Write handler**

Thin MediatR query that builds a `ZonePricingQuery` from the DTO and delegates to `IZonePricingResolver.TryResolveAsync`. Maps the result to response DTO with `matched` flag. Structured logging with query → result summary.

- [ ] **Step 2: Build + commit**

```bash
cd src/backend && dotnet build --nologo -v minimal 2>&1 | tail -3
git add src/backend/RedTaxi.Application/Features/ZonePricing/Quote/
git commit -m "feat(zone-pricing): standalone quote endpoint handler"
```

---

### Task 10: Controller + DI registration

**Files:**
- Create: `src/backend/RedTaxi.API/Controllers/V2/ZonePricingController.cs`
- Modify: `src/backend/RedTaxi.API/Program.cs`

- [ ] **Step 1: Write controller (routing only)**

```csharp
[ApiController]
[Route("api/v2/zone-pricing")]
[ApiExplorerSettings(GroupName = "v2")]
[Authorize(Roles = "Admin")]  // Operator+ on /quote, overridden per-method
public class ZonePricingController : ControllerBase
{
    private readonly IMediator _mediator;
    public ZonePricingController(IMediator mediator) => _mediator = mediator;

    [HttpGet("zones")] public async Task<IActionResult> ListZones([FromQuery] bool includeInactive = false) =>
        (await _mediator.Send(new ListZones.Query(includeInactive))).ToActionResult();

    [HttpGet("zones/{id:int}")] public async Task<IActionResult> GetZone(int id) =>
        (await _mediator.Send(new GetZone.Query(id))).ToActionResult();

    [HttpPost("zones")] public async Task<IActionResult> CreateZone([FromBody] CreateZone.Command cmd) =>
        (await _mediator.Send(cmd)).ToCommandResult();

    [HttpPut("zones/{id:int}")] public async Task<IActionResult> UpdateZone(int id, [FromBody] UpdateZone.Command cmd) =>
        (await _mediator.Send(cmd with { Id = id })).ToCommandResult();

    [HttpDelete("zones/{id:int}")] public async Task<IActionResult> DeleteZone(int id) =>
        (await _mediator.Send(new DeleteZone.Command(id))).ToCommandResult();

    [HttpPost("zones/validate")] public async Task<IActionResult> ValidateZone([FromBody] ValidateZone.Query q) =>
        (await _mediator.Send(q)).ToActionResult();

    [HttpGet("matrix")] public async Task<IActionResult> ListMatrix([FromQuery] int? accountNo) =>
        (await _mediator.Send(new ListMatrix.Query(accountNo))).ToActionResult();

    [HttpPut("matrix")] public async Task<IActionResult> UpsertMatrix([FromBody] UpsertMatrix.Command cmd) =>
        (await _mediator.Send(cmd)).ToCommandResult();

    [HttpDelete("matrix/{id:int}")] public async Task<IActionResult> DeleteMatrixRow(int id) =>
        (await _mediator.Send(new DeleteMatrixRow.Command(id))).ToCommandResult();

    [HttpGet("matrix/export")] public async Task<IActionResult> ExportMatrix([FromQuery] int? accountNo) {
        var r = await _mediator.Send(new ExportMatrix.Query(accountNo));
        return r.IsSuccess
            ? File(System.Text.Encoding.UTF8.GetBytes(r.Value!), "text/csv", $"zone-matrix-{DateTime.UtcNow:yyyyMMdd}.csv")
            : r.ToActionResult();
    }

    [HttpPost("matrix/import")] public async Task<IActionResult> ImportMatrix([FromForm] IFormFile file) {
        using var sr = new StreamReader(file.OpenReadStream());
        var csv = await sr.ReadToEndAsync();
        return (await _mediator.Send(new ImportMatrix.Command(csv))).ToCommandResult();
    }

    [HttpPost("quote")]
    [Authorize(Roles = "Admin,Operator")]
    public async Task<IActionResult> GetQuote([FromBody] GetZoneQuote.Query q) =>
        (await _mediator.Send(q)).ToActionResult();
}
```

- [ ] **Step 2: DI in `Program.cs`**

In the services registration section (near other `AddScoped` pricing services):
```csharp
builder.Services.AddSingleton<ZoneCacheInvalidator>();
builder.Services.AddScoped<IZoneGeometryService, ZoneGeometryService>();
builder.Services.AddScoped<IPostcodeGeocoder, PostcodeGeocoder>();
builder.Services.AddScoped<IZonePricingResolver, ZonePricingResolver>();
```

- [ ] **Step 3: Build**

```bash
cd src/backend && dotnet build --nologo -v minimal 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add src/backend/RedTaxi.API/
git commit -m "feat(zone-pricing): v2 controller + DI registration"
```

---

### Task 11: Snapshot tests

**Files:**
- Create: `src/backend/RedTaxi.Tests/SnapshotTests/ZonePricingSnapshotTests.cs`

- [ ] **Step 1: Write snapshot tests per spec §5.5**

Use existing `WebApplicationFactory<Program>` + `Verify`. Base class has helpers `VerifyGet`, `VerifyPost`.

12 scenarios:
1. `GET zones` empty tenant
2. `POST zones` valid polygon (seeds one zone, snapshot the response)
3. `POST zones` too-few-points → 400 + error shape
4. `POST zones` self-intersecting → 400
5. `POST zones` overlapping → 400 + offending zoneId
6. `POST zones` duplicate name → 400
7. `POST zones/validate` self-intersecting → 200 with issues[]
8. `PUT matrix` with valid row → 200
9. `PUT matrix` with diagonal (FromZoneId==ToZoneId) → 400
10. `POST matrix/import` valid CSV → 200 with counts
11. `POST quote` matched → 200 with price
12. `POST quote` unmatched → 200 with matched:false

- [ ] **Step 2: Run snapshots, accept initial baselines**

```bash
cd src/backend
dotnet test RedTaxi.Tests --filter "FullyQualifiedName~ZonePricingSnapshotTests" --nologo --no-restore 2>&1 | tail -15
```

Review `.received.txt` files, rename to `.verified.txt` for first run. Commit verified files.

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Tests/SnapshotTests/
git commit -m "test(zone-pricing): snapshot tests for 12 scenarios"
```

---

### Task 12: Seed default tenant settings

**Files:**
- Modify: `src/backend/RedTaxi.Data/Seeds/TenantSettingsSeeder.cs` (or wherever defaults are set)

- [ ] **Step 1: Add defaults for new tenants**

Register default values (`ZonePricing.Enabled=false`, `Tariff2Multiplier=1.25`, etc.). Existing tenants will read defaults from `ITenantConfigService.GetAsync(key, defaultValue)` — no DB rows required.

- [ ] **Step 2: Commit**

```bash
git add .
git commit -m "chore(zone-pricing): add default ZonePricing settings"
```

---

### Task 13: Admin UI — zones page (map editor)

**Files:**
- Create: `src/frontend/apps/admin-v2/src/app/(dashboard)/settings/zone-pricing/zones/page.tsx`
- Create: `src/frontend/apps/admin-v2/src/components/admin/zone-editor/ZoneMap.tsx`
- Create: `.../zone-editor/ZoneSidebar.tsx`
- Create: `.../zone-editor/ZoneSaveDialog.tsx`
- Create: `.../zone-editor/ZoneDeleteDialog.tsx`
- Create: `.../zone-editor/snap-helpers.ts`
- Create: `.../zone-editor/geometry-helpers.ts`
- Create: `.../lib/hooks/use-zones.ts`
- Modify: `.../lib/navigation.ts`

- [ ] **Step 1: Add nav entry**

In `navigation.ts`, under Settings section add:
```ts
{ label: "Zone Pricing", icon: MapIcon, children: [
  { label: "Zones", href: "/settings/zone-pricing/zones" },
  { label: "Price Matrix", href: "/settings/zone-pricing/matrix" },
]}
```

- [ ] **Step 2: Write TanStack Query hooks (`use-zones.ts`)**

`useZones()`, `useZone(id)`, `useCreateZone()`, `useUpdateZone()`, `useDeleteZone()`, `useValidateZone()`.

- [ ] **Step 3: Write snap math (`snap-helpers.ts`)**

Pure functions:
- `projectPointToSegment(p, a, b)` — perpendicular projection with clamp
- `distancePx(latLngA, latLngB, map)` — via `map.getProjection()`
- `findNearestEdgeSnap(cursor, zones, thresholdPx, map)` → `{ snapped: {lat,lng}, zoneId } | null`
- `findNearestVertexSnap(cursor, zones, thresholdPx, map)` → similar
- `findCloseSnap(cursor, firstVertex, thresholdPx, map)` → similar

- [ ] **Step 4: Write `ZoneMap.tsx`**

Renders Google Maps via `<APIProvider>` + `<Map>`. Loads `['drawing', 'geometry']` libraries. When in draw mode, attaches a custom click listener that runs snap helpers before accepting the vertex. Renders existing zones as `<Polygon>` overlays. Visual feedback:
- Red stroke when self-intersecting (from `validate` endpoint call)
- Red shaded overlay when overlap detected
- First vertex glows when within snap-close threshold
- Snap indicator (green ring) on snapped locations

- [ ] **Step 5: Write `ZoneSidebar.tsx`**

Lists zones with coloured dots, area, vertex count. Row click → highlight on map + enter edit mode. Delete button confirms via `ZoneDeleteDialog`.

- [ ] **Step 6: Write `ZoneSaveDialog.tsx`** — name input + save

- [ ] **Step 7: Write `ZoneDeleteDialog.tsx`** — uses existing `ConfirmDialog` pattern

- [ ] **Step 8: Write page shell** — composes the above

- [ ] **Step 9: Build admin-v2**

```bash
cd src/frontend/apps/admin-v2 && npm run build 2>&1 | tail -5
```

- [ ] **Step 10: Commit**

```bash
git add src/frontend/apps/admin-v2/
git commit -m "feat(zone-pricing): admin UI — zones page with map drawing editor"
```

---

### Task 14: Admin UI — matrix page

**Files:**
- Create: `src/frontend/apps/admin-v2/src/app/(dashboard)/settings/zone-pricing/matrix/page.tsx`
- Create: `.../zone-editor/MatrixGrid.tsx`
- Create: `.../zone-editor/PricingSettingsCard.tsx`
- Create: `.../zone-editor/MatrixCsvImportDialog.tsx`
- Create: `.../lib/hooks/use-zone-matrix.ts`

- [ ] **Step 1: Write TanStack hooks**

`useMatrix(accountNo?)`, `useUpsertMatrix()`, `useDeleteMatrixRow()`, `useMatrixCsvExport()`, `useMatrixCsvImport()`.

- [ ] **Step 2: Write `MatrixGrid.tsx`**

Table: rows = zones (From), columns = zones (To). Each cell has Cost + Price inputs (numeric, no spinners per admin-v2 CLAUDE.md rule #12). Diagonal disabled. "Save All Changes" button triggers `upsertMatrix` with changed rows. Track changes in local state keyed by `fromZoneId:toZoneId`.

- [ ] **Step 3: Write `PricingSettingsCard.tsx`**

Side card with `ZonePricing.Enabled` Switch, `Tariff2Multiplier`, `Tariff3Multiplier`, `StopFee`, `DetourThresholdMiles`, `DetourPerMileRate`. Uses existing `/api/v2/settings` hooks.

- [ ] **Step 4: Write `MatrixCsvImportDialog.tsx`**

File picker → POST → show `{inserted, updated, errors}` summary. Error rows listed in a modal table.

- [ ] **Step 5: Write page shell**

Two-column layout. Account scope chips at top (Cash defaulted in PR1).

- [ ] **Step 6: Build admin-v2 + deploy to staging**

```bash
cd src/frontend/apps/admin-v2 && npm run build 2>&1 | tail -5
powershell -Command "nssm restart redtaxi-admin"
```

- [ ] **Step 7: Commit**

```bash
git add src/frontend/apps/admin-v2/
git commit -m "feat(zone-pricing): admin UI — matrix page + settings + CSV import/export"
```

---

### Task 15: Browser QA via Chrome DevTools MCP

- [ ] **Step 1: Deploy API to staging**

```bash
powershell -Command "nssm stop redtaxi-api"
cd src/backend && dotnet publish RedTaxi.API/RedTaxi.API.csproj -c Release -o ../../staging/api-publish --nologo 2>&1 | tail -3
powershell -Command "nssm start redtaxi-api"
curl -s -o /dev/null -w "API: %{http_code}\n" https://staging-api.redtaxi.co.uk/health
```

- [ ] **Step 2: Apply migration on staging DB**

Local Postgres is the staging DB — already applied in Task 3.

- [ ] **Step 3: Chrome DevTools QA — zone editor**

Via `mcp__chrome-devtools__navigate_page` to `https://staging-app.redtaxi.co.uk/settings/zone-pricing/zones`. Draw a test polygon "Test Zone A". Take screenshot. Attempt to draw an overlapping polygon. Verify save blocked. Take screenshot.

- [ ] **Step 4: Chrome DevTools QA — matrix**

Navigate to `/settings/zone-pricing/matrix`. Enter a cost/price pair. Save. Reload. Verify persisted. Take screenshot.

- [ ] **Step 5: Smoke-test CSV round-trip**

Export → re-import. Verify no duplicate rows.

- [ ] **Step 6: Curl walk of quote endpoint**

```bash
TOKEN=$(curl -s "https://staging-api.redtaxi.co.uk/dev/token?user=Peter" | python -c "import sys,json;print(json.load(sys.stdin)['token'])")
# Create zones
curl -X POST https://staging-api.redtaxi.co.uk/api/v2/zone-pricing/zones \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"Gillingham","points":[{"lat":51.03,"lng":-2.28},{"lat":51.03,"lng":-2.26},{"lat":51.05,"lng":-2.26},{"lat":51.05,"lng":-2.28}]}'
# ... repeat for Heathrow
# Upsert matrix
# Query quote
```

Capture every response. Log to a smoke-results file.

- [ ] **Step 7: Document screenshots in PR body**

---

### Task 16: Open PR1

- [ ] **Step 1: Run code reviewer**

Use `code-reviewer` agent on the full diff vs `dev`. Fix issues before PR.

- [ ] **Step 2: Open PR**

```bash
gh pr create --base dev --head feature/zone-zone-pricing --title "feat(zone-pricing): admin CRUD + quote endpoint (PR1)" --body "$(cat <<'EOF'
## Summary

Phase 1 of zone-to-zone polygon pricing. Adds:
- `ZonePolygons` + `ZonePriceMatrix` + `PostcodeCoordinates` tenant tables
- `Booking.{Pickup,Destination}{Lat,Lng}` + `PriceSource` columns (nullable, default 'mileage')
- `IZonePricingResolver` (not yet wired into CreateBooking — that's PR2)
- Standalone `POST /api/v2/zone-pricing/quote` endpoint
- Admin UI: `/settings/zone-pricing/zones` (map editor) + `/settings/zone-pricing/matrix`
- CSV import/export
- 12 snapshot tests + unit tests for geometry + resolver
- V1 `GeoFences` and `ZoneToZonePrices` tables untouched — zero v1 contract change

## Test plan

- [x] All snapshot tests pass
- [x] Geometry unit tests pass
- [x] Resolver unit tests pass
- [x] Staging: draw polygon + save → persisted
- [x] Staging: draw overlapping polygon → blocked
- [x] Staging: matrix upsert → persisted
- [x] Staging: CSV round-trip → no data loss
- [x] Staging: quote endpoint matches + fallbacks correctly

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Phase 2 — PR2 (integration into all pricing paths)

### Task 17: Inject resolver into `GetCashPrice`

**Files:**
- Modify: `src/backend/RedTaxi.Application/Features/Pricing/GetCashPrice.cs`

- [ ] **Step 1: Inject `IZonePricingResolver` + call before tariff logic**

Before calling `TariffService.Get9999CashPrice`, call the resolver:
```csharp
var zoneResult = await _zoneResolver.TryResolveAsync(BuildZoneQuery(request), ct);
if (zoneResult != null) {
    return Result.Ok(new GetCashPriceResponse {
        Price = zoneResult.Price,
        Cost = zoneResult.Cost,
        Mileage = 0,  // placeholder, or compute direct miles for reporting
        FromZone = new ZoneRef(zoneResult.FromZoneId, zoneResult.FromZoneName),
        ToZone = new ZoneRef(zoneResult.ToZoneId, zoneResult.ToZoneName),
        Tariff = zoneResult.Tariff,
        Reason = zoneResult.Reason,
    });
}
// existing mileage path unchanged
```

- [ ] **Step 2: Extend response DTO with optional `FromZone`, `ToZone`, `Reason`**

- [ ] **Step 3: Add two snapshot tests (zone-hit + zone-miss)**

- [ ] **Step 4: Build + commit**

```bash
git commit -m "feat(zone-pricing): wire resolver into GetCashPrice handler"
```

---

### Task 18: Inject resolver into `CreateBooking`

**Files:**
- Modify: `src/backend/RedTaxi.Application/Features/Bookings/CreateBooking.cs`

- [ ] **Step 1: Call resolver. If zone-priced, populate `Booking.Price`, `Booking.PriceSource = "zone"`. Also populate `PickupLat/Lng` + `DestinationLat/Lng` from the request if present.**

- [ ] **Step 2: Write snapshot tests**

- [ ] **Step 3: Commit**

---

### Task 19: Inject resolver into `GetDuration` (web booking)

**Files:**
- Modify: `src/backend/RedTaxi.Application/Features/WebBookings/GetDuration.cs`

Same pattern.

---

### Task 20: AI agent integration (transparent via MediatR)

WhatsApp + Voice agents already route through `GetCashPrice` → nothing new to wire. Verify by calling the WhatsApp agent via the test harness with a zone-matched route and confirming the response includes zone metadata.

- [ ] **Step 1: Run voice agent tuning harness test with zone-matched route**

```bash
cd src/backend/RedTaxi.AI/tuning
python test_voice_call.py --scenario gill-to-heathrow
```

Expected: zone price returned.

- [ ] **Step 2: Run WhatsApp agent test with zone-matched query**

Post a test WhatsApp message via the agent test harness: "how much from gillingham to heathrow". Expected: £225 (or whatever the matrix row says).

- [ ] **Step 3: Extend `IntelligenceCache.LookupRoute` to include zone-priced flag**

Wrap the return value: if resolver matches, return `CachedRoute` with `PriceSource = "zone"` + the matched price. Else existing behaviour.

- [ ] **Step 4: Commit**

---

### Task 21: Price-source chip in dispatch booking form

**Files:**
- Create: `src/frontend/apps/admin-v2/src/components/admin/zone-editor/PriceSourceChip.tsx` (shared)
- Create: `src/frontend/apps/headless-dispatch/src/components/BookingForm/PriceSourceChip.jsx` (copy of above, JSX form)
- Modify: `src/frontend/apps/headless-dispatch/src/components/BookingForm/QuoteDialog.jsx`
- Modify: `src/frontend/apps/headless-dispatch/src/pages/Booking.jsx` (wherever price renders inline)

- [ ] **Step 1: Write `PriceSourceChip.jsx`**

Renders `ZONE · Gill → LHR · £225` when `priceSource === "zone"`, else `MILEAGE · £47`. Color: green for zone, muted for mileage.

- [ ] **Step 2: Extend `getPrice` API call to pass lat/lng + receive zone metadata**

- [ ] **Step 3: Render chip next to price in QuoteDialog + Booking form**

- [ ] **Step 4: Build headless-dispatch + deploy**

```bash
cd src/frontend/apps/headless-dispatch && npm run build
# IIS serves dist/ directly
```

- [ ] **Step 5: Commit**

---

### Task 22: E2E smoke on staging

- [ ] **Step 1: Scripted curl walk**

Run the full scenario walk from spec §9.4 against staging. Any failure halts the loop.

- [ ] **Step 2: Chrome DevTools QA — end-to-end booking**

1. Create a zone-priced booking via dispatch booking form.
2. Verify price chip says ZONE and matches the matrix value.
3. Allocate the booking.
4. Verify WhatsApp template fired with correct price.
5. Check `Booking.PriceSource = 'zone'` in DB.

Screenshots of each step attached to PR.

---

### Task 23: Open PR2

- [ ] **Step 1: Code review agent on full diff**

- [ ] **Step 2: Open PR**

```bash
gh pr create --base dev --head feature/zone-zone-pricing --title "feat(zone-pricing): integrate resolver into dispatch + AI agents (PR2)" ...
```

---

## Testing Summary

| Type | Count | Location |
|---|---|---|
| Unit — geometry | 10 | `RedTaxi.Tests/UnitTests/ZoneGeometryServiceTests.cs` |
| Unit — resolver | 8 | `RedTaxi.Tests/UnitTests/ZonePricingResolverTests.cs` |
| Snapshot — PR1 | 12 | `RedTaxi.Tests/SnapshotTests/ZonePricingSnapshotTests.cs` |
| Snapshot — PR2 | 4 | Extend `BookingsSnapshotTests` + `V2SnapshotTests` |
| Browser QA | 6 | Chrome DevTools MCP walks (screenshots in PR) |
| E2E curl | 6 | `scripts/smoke-zone-pricing.sh` |

---

## Done criteria

- [ ] Both PRs merged to dev
- [ ] Staging API healthy after both deploys
- [ ] Admin-v2 staging shows zone editor + matrix pages
- [ ] Zone creation blocks overlaps
- [ ] Quote endpoint returns correct prices for all 6 scenarios
- [ ] A real booking created via dispatch with zone-priced route shows ZONE chip + correct price
- [ ] WhatsApp test message "how much from X to Y" returns zone price
- [ ] All snapshot + unit tests green
- [ ] No v1 endpoint regressions (run existing suite)

---

## Out of scope (deferred to follow-up PRs)

Per spec §8.2:
1. Operator lat/lng backfill script
2. Address picker lat/lng capture in `CreateBooking` write path
3. Per-account scope UI unlock
4. MPV separate matrix
5. V1 table cleanup
