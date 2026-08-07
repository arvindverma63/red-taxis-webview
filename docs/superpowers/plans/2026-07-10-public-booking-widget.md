# Public Booking Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embeddable, themeable `<redtaxi-booking>` widget any tenant site can drop in, backed by a new anonymous-but-tenant-keyed `/api/v2/public/*` surface; first deployment on the First Taxis site against staging.

**Architecture:** Backend adds `X-Tenant-Key` resolution to `TenantResolutionMiddleware` and a thin `PublicBookingController` that delegates to existing MediatR handlers (GetCashPrice, AddressSearch/Resolve) plus one new `CreatePublicBooking` handler modelled on `CreateCustomerBookingRequest`. Widget is a Vite lib-mode IIFE bundle registering a custom element (React in Shadow DOM), configured by attributes, themed by `--rt-*` CSS custom properties. First Taxis mounts it in compact (home hero) and full (`/book-online`) modes.

**Tech Stack:** ASP.NET Core (net8, MediatR, Dapper/Npgsql control DB, xunit), React 18 + TypeScript + Vite (lib mode), vitest, Playwright.

**Repos/worktrees:**
- Backend + widget: `O:\RedTaxi\.claude\worktrees\booking-widget-v2` (branch `feature/public-booking-widget` off `dev`)
- Site: `O:\projects\red-banana\owned\first-taxis\.claude\worktrees\redtaxi-quote-form-api-503eb9` (branch `claude/redtaxi-quote-form-api-503eb9`)

**Spec:** `docs/superpowers/specs/2026-07-10-public-booking-widget-design.md`

**Conventions that MUST be followed (from the existing code):**
- v2 envelope: `{ success, data, errors: [{ code, message }] }`. Handlers return `Result<T>` (`RedTaxi.Domain`); controllers call `result.ToActionResult("ERROR_CODE")` (`RedTaxi.API.Extensions`).
- MediatR feature files: one static class per feature in `RedTaxi.Application/Features/<Area>/`, containing `record Command/Query(...) : IRequest<Result<T>>` + nested `Handler`.
- DTOs live in `RedTaxi.Application/DTOs/<Area>/` under namespace `RedTaxi.DTOs.<Area>`.
- UK time via `DateTime.Now.ToUKTime()`; cash account constant `SystemAccounts.Cash`; web bookings are `WebBooking` rows with `Status = WebBookingStatus.Default, Processed = false`.
- Tests: xunit in `src/backend/RedTaxi.Tests` (plain unit tests in `UnitTests/`, DB-dependent tests use `LocalDbFactAttribute`).

---

### Task 1: Tenant public key — control DB column + middleware resolution (TDD)

**Files:**
- Create: `src/backend/scripts/control-db/2026-07-10-add-organization-public-key.sql`
- Modify: `src/backend/RedTaxi.API/Middleware/TenantResolutionMiddleware.cs`
- Test: `src/backend/RedTaxi.Tests/UnitTests/PublicTenantKeyMiddlewareTests.cs`

- [ ] **Step 1: Write the SQL migration script** (idempotent; applied to `redtaxi_control` on staging in Task 6)

```sql
-- Adds the public widget key to organizations. NULL = tenant not enabled for public booking.
ALTER TABLE organization ADD COLUMN IF NOT EXISTS public_key TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS ux_organization_public_key
    ON organization (public_key) WHERE public_key IS NOT NULL;
```

- [ ] **Step 2: Write failing middleware tests**

`PublicTenantKeyMiddlewareTests.cs` — these exercise the no-DB paths (missing header / OPTIONS skip) and the envelope shape; the invalid-key DB path uses an unreachable control DB (lookup returns null → 401):

```csharp
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using RedTaxi.API.Middleware;
using System.Text.Json;
using Xunit;

namespace RedTaxi.Tests.UnitTests;

public class PublicTenantKeyMiddlewareTests
{
    private static (TenantResolutionMiddleware mw, DefaultHttpContext ctx, Func<bool> nextCalled) Make()
    {
        var called = false;
        RequestDelegate next = _ => { called = true; return Task.CompletedTask; };
        var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            // Unreachable control DB: any key lookup fails fast and resolves to null.
            ["ConnectionStrings:ControlDb"] = "Host=127.0.0.1;Port=1;Database=none;Username=x;Password=x;Timeout=1",
            ["ConnectionStrings:DefaultConnection"] = "Host=127.0.0.1;Port=1;Database=none;Username=x;Password=x;Timeout=1",
        }).Build();
        var mw = new TenantResolutionMiddleware(next, config);
        var ctx = new DefaultHttpContext();
        ctx.Response.Body = new MemoryStream();
        return (mw, ctx, () => called);
    }

    private static JsonElement ReadBody(DefaultHttpContext ctx)
    {
        ctx.Response.Body.Position = 0;
        using var doc = JsonDocument.Parse(new StreamReader(ctx.Response.Body).ReadToEnd());
        return doc.RootElement.Clone();
    }

    [Fact]
    public async Task PublicRoute_MissingKey_Returns401Envelope()
    {
        var (mw, ctx, nextCalled) = Make();
        ctx.Request.Method = "POST";
        ctx.Request.Path = "/api/v2/public/pricing/quote";

        await mw.InvokeAsync(ctx);

        Assert.Equal(401, ctx.Response.StatusCode);
        Assert.False(nextCalled());
        var body = ReadBody(ctx);
        Assert.False(body.GetProperty("success").GetBoolean());
        Assert.Equal("TENANT_KEY_REQUIRED", body.GetProperty("errors")[0].GetProperty("code").GetString());
    }

    [Fact]
    public async Task PublicRoute_UnknownKey_Returns401Envelope_NoDefaultFallback()
    {
        var (mw, ctx, nextCalled) = Make();
        ctx.Request.Method = "POST";
        ctx.Request.Path = "/api/v2/public/bookings/request";
        ctx.Request.Headers["X-Tenant-Key"] = "rtk_pub_does_not_exist";

        await mw.InvokeAsync(ctx);

        Assert.Equal(401, ctx.Response.StatusCode);
        Assert.False(nextCalled());
        Assert.Null(ctx.Items["TenantConnectionString"]); // never fell back to default tenant
        var body = ReadBody(ctx);
        Assert.Equal("TENANT_KEY_INVALID", body.GetProperty("errors")[0].GetProperty("code").GetString());
    }

    [Fact]
    public async Task PublicRoute_OptionsPreflight_SkipsKeyCheck()
    {
        // Browser preflights carry no custom headers; they must pass through so CORS can answer.
        var (mw, ctx, nextCalled) = Make();
        ctx.Request.Method = "OPTIONS";
        ctx.Request.Path = "/api/v2/public/pricing/quote";

        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled());
        Assert.NotEqual(401, ctx.Response.StatusCode);
    }

    [Fact]
    public async Task NonPublicAnonymousRoute_StillGetsDefaultTenant()
    {
        var (mw, ctx, nextCalled) = Make();
        ctx.Request.Method = "GET";
        ctx.Request.Path = "/health";

        await mw.InvokeAsync(ctx);

        Assert.True(nextCalled());
        Assert.NotNull(ctx.Items["TenantConnectionString"]);
    }
}
```

- [ ] **Step 3: Run tests, verify the new ones FAIL**

```
cd src/backend && dotnet test RedTaxi.Tests --filter PublicTenantKeyMiddlewareTests -v minimal
```
Expected: FAIL (public routes currently fall into the default-tenant branch → no 401, `nextCalled` true).

- [ ] **Step 4: Implement middleware changes**

In `TenantResolutionMiddleware.cs` add near the other statics:

```csharp
private const string PublicRoutePrefix = "/api/v2/public/";
private const string TenantKeyHeader = "X-Tenant-Key";
private static readonly ConcurrentDictionary<string, (string OrgId, string ConnStr)> _publicKeyCache = new();
```

In `InvokeAsync`, inside the `else` (no JWT org claim) branch, BEFORE the login/refresh checks, insert:

```csharp
var pathRaw = context.Request.Path.Value?.ToLowerInvariant() ?? "";

// Public widget surface: tenant comes from X-Tenant-Key. Fails closed —
// a misconfigured widget must never book into the default tenant.
// OPTIONS is exempt: CORS preflights cannot carry custom headers.
if (pathRaw.StartsWith(PublicRoutePrefix) && context.Request.Method != "OPTIONS")
{
    var key = context.Request.Headers[TenantKeyHeader].FirstOrDefault();
    if (string.IsNullOrWhiteSpace(key))
    {
        context.Response.StatusCode = 401;
        await context.Response.WriteAsJsonAsync(new { success = false, data = (object?)null, errors = new[] { new { code = "TENANT_KEY_REQUIRED", message = "X-Tenant-Key header is required." } } });
        return;
    }

    var tenant = await ResolveTenantByPublicKey(key);
    if (tenant == null)
    {
        Log.Warning("Public booking request rejected: unknown tenant key {KeyPrefix}...", key.Length > 12 ? key[..12] : key);
        context.Response.StatusCode = 401;
        await context.Response.WriteAsJsonAsync(new { success = false, data = (object?)null, errors = new[] { new { code = "TENANT_KEY_INVALID", message = "Tenant key is not recognised." } } });
        return;
    }

    context.Items["TenantConnectionString"] = tenant.Value.ConnStr;
    context.Items["TenantOrgId"] = tenant.Value.OrgId;
    await _next(context);
    return;
}
```

(The existing `var path = ...` line below stays; keep both or reuse `pathRaw` — reuse is cleaner: rename existing `path` usage accordingly.)

Add the resolver alongside `ResolveTenantConnectionString`:

```csharp
private async Task<(string OrgId, string ConnStr)?> ResolveTenantByPublicKey(string publicKey)
{
    if (_publicKeyCache.TryGetValue(publicKey, out var cached)) return cached;

    try
    {
        await using var conn = new NpgsqlConnection(_controlDbConnectionString);
        await conn.OpenAsync();

        var row = await conn.QueryFirstOrDefaultAsync<(string id, string database_url)?>(
            "SELECT id, database_url FROM organization WHERE public_key = @Key AND status NOT IN ('hard_locked', 'deleted')",
            new { Key = publicKey });

        if (row == null) return null;

        var connStr = row.Value.database_url;
        if (connStr.StartsWith("postgres")) connStr = ConvertPostgresUrl(connStr);

        var resolved = (row.Value.id, connStr);
        _publicKeyCache[publicKey] = resolved;
        return resolved;
    }
    catch (Exception ex)
    {
        Log.Warning(ex, "Failed to resolve tenant by public key");
        return null;
    }
}
```

- [ ] **Step 5: Run tests, verify PASS**

```
cd src/backend && dotnet test RedTaxi.Tests --filter PublicTenantKeyMiddlewareTests -v minimal
```
Expected: 4 PASS. Also run the full suite once (`dotnet test RedTaxi.Tests -v minimal`) to prove no regression in existing middleware behaviour.

- [ ] **Step 6: Commit**

```bash
git add src/backend/scripts/control-db/2026-07-10-add-organization-public-key.sql src/backend/RedTaxi.API/Middleware/TenantResolutionMiddleware.cs src/backend/RedTaxi.Tests/UnitTests/PublicTenantKeyMiddlewareTests.cs
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "feat(api): resolve tenant from X-Tenant-Key on /api/v2/public routes"
```

---

### Task 2: Public booking DTOs + validator (TDD)

**Files:**
- Create: `src/backend/RedTaxi.Application/DTOs/PublicBooking/PublicBookingDtos.cs`
- Create: `src/backend/RedTaxi.Application/Features/PublicBooking/PublicBookingValidator.cs`
- Test: `src/backend/RedTaxi.Tests/UnitTests/PublicBookingValidatorTests.cs`

Validation lives in a pure static class so every edge case is unit-testable without a DbContext.

- [ ] **Step 1: Write the DTOs**

```csharp
using RedTaxi.DTOs.CustomerApp;

namespace RedTaxi.DTOs.PublicBooking
{
    /// <summary>
    /// Guest booking request from the embeddable website widget
    /// (<c>POST /api/v2/public/bookings/request</c>). Anonymous — passenger
    /// identity travels in the payload, unlike the customer-app variant.
    /// Cash-only by design; tenant comes from X-Tenant-Key.
    /// </summary>
    public class CreatePublicBookingRequestDto
    {
        public CustomerPlaceDto? Pickup { get; set; }
        public CustomerPlaceDto? Destination { get; set; }
        public List<CustomerPlaceDto> Vias { get; set; } = new();
        public int Passengers { get; set; } = 1;
        public DateTime? ScheduledFor { get; set; }
        public bool Asap { get; set; }
        public string? PassengerName { get; set; }
        public string? PhoneNumber { get; set; }
        public string? Email { get; set; }
        public string? Details { get; set; }
        public PublicQuoteDto? Quote { get; set; }
    }

    public class PublicQuoteDto
    {
        public double? PriceCash { get; set; }
    }

    public class PublicBookingCreatedDto
    {
        public string RequestId { get; set; } = string.Empty;
        public string Status { get; set; } = "pending";
    }
}
```

- [ ] **Step 2: Write failing validator tests**

```csharp
using RedTaxi.Application.Features.PublicBooking;
using RedTaxi.DTOs.CustomerApp;
using RedTaxi.DTOs.PublicBooking;
using Xunit;

namespace RedTaxi.Tests.UnitTests;

public class PublicBookingValidatorTests
{
    private static CreatePublicBookingRequestDto Valid() => new()
    {
        Pickup = new CustomerPlaceDto { Description = "12 Station Road, Gillingham", Postcode = "SP8 4QA" },
        Destination = new CustomerPlaceDto { Description = "High Street, Shaftesbury", Postcode = "SP7 8JE" },
        Passengers = 2,
        ScheduledFor = DateTime.Now.AddHours(3),
        PassengerName = "Jane Doe",
        PhoneNumber = "07700900123",
        Email = "jane@example.com",
        Quote = new PublicQuoteDto { PriceCash = 24.50 }
    };

    [Fact] public void Valid_request_passes() => Assert.Null(PublicBookingValidator.Validate(Valid()));

    [Fact] public void Missing_pickup_fails()
    { var d = Valid(); d.Pickup = null; Assert.Contains("Pickup", PublicBookingValidator.Validate(d)); }

    [Fact] public void Missing_pickup_postcode_fails()
    { var d = Valid(); d.Pickup!.Postcode = " "; Assert.Contains("postcode", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Fact] public void Missing_passenger_name_fails()
    { var d = Valid(); d.PassengerName = ""; Assert.Contains("name", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Fact] public void Missing_phone_fails()
    { var d = Valid(); d.PhoneNumber = null; Assert.Contains("phone", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Fact] public void Past_pickup_fails()
    { var d = Valid(); d.ScheduledFor = DateTime.Now.AddMinutes(-30); d.Asap = false; Assert.Contains("past", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Fact] public void Asap_ignores_scheduled_time()
    { var d = Valid(); d.ScheduledFor = DateTime.Now.AddMinutes(-30); d.Asap = true; Assert.Null(PublicBookingValidator.Validate(d)); }

    [Fact] public void Pickup_equals_destination_fails()
    { var d = Valid(); d.Destination = new CustomerPlaceDto { Description = d.Pickup!.Description, Postcode = d.Pickup.Postcode }; Assert.Contains("same", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Theory]
    [InlineData(0)] [InlineData(9)] [InlineData(-1)]
    public void Passengers_out_of_range_fails(int n)
    { var d = Valid(); d.Passengers = n; Assert.Contains("passengers", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }

    [Fact] public void Name_over_250_fails()
    { var d = Valid(); d.PassengerName = new string('a', 251); Assert.NotNull(PublicBookingValidator.Validate(d)); }

    [Fact] public void Phone_over_20_fails()
    { var d = Valid(); d.PhoneNumber = new string('1', 21); Assert.NotNull(PublicBookingValidator.Validate(d)); }

    [Fact] public void Details_over_2000_fails()
    { var d = Valid(); d.Details = new string('x', 2001); Assert.NotNull(PublicBookingValidator.Validate(d)); }

    [Fact] public void Missing_quote_fails()
    { var d = Valid(); d.Quote = null; Assert.Contains("quote", PublicBookingValidator.Validate(d)!, StringComparison.OrdinalIgnoreCase); }
}
```

- [ ] **Step 3: Run, verify FAIL** — `dotnet test RedTaxi.Tests --filter PublicBookingValidatorTests -v minimal` → compile error (validator missing).

- [ ] **Step 4: Implement the validator**

```csharp
using RedTaxi.Data;
using RedTaxi.DTOs.PublicBooking;

namespace RedTaxi.Application.Features.PublicBooking;

/// <summary>
/// Pure validation for guest widget bookings. Returns null when valid,
/// otherwise a customer-readable error message (surfaced in the v2 envelope).
/// Limits mirror the WebBooking column constraints (address 250, postcode 9,
/// name 250, phone 20, email 250, details 2000).
/// </summary>
public static class PublicBookingValidator
{
    public static string? Validate(CreatePublicBookingRequestDto dto)
    {
        if (dto.Pickup == null || string.IsNullOrWhiteSpace(dto.Pickup.Description))
            return "Pickup address is required.";
        if (dto.Destination == null || string.IsNullOrWhiteSpace(dto.Destination.Description))
            return "Destination address is required.";
        if (string.IsNullOrWhiteSpace(dto.Pickup.Postcode) || string.IsNullOrWhiteSpace(dto.Destination.Postcode))
            return "A postcode is required for pickup and destination.";
        if (dto.Pickup.Postcode.Trim().Length > 9 || dto.Destination.Postcode.Trim().Length > 9)
            return "Postcode is not valid.";

        var samePlace = string.Equals(dto.Pickup.Postcode.Trim(), dto.Destination.Postcode.Trim(), StringComparison.OrdinalIgnoreCase)
            && string.Equals(dto.Pickup.Description.Trim(), dto.Destination.Description.Trim(), StringComparison.OrdinalIgnoreCase);
        if (samePlace)
            return "Pickup and destination cannot be the same place.";

        if (dto.Pickup.Description.Length > 250 || dto.Destination.Description.Length > 250)
            return "Address is too long (250 characters max).";

        if (string.IsNullOrWhiteSpace(dto.PassengerName))
            return "Passenger name is required.";
        if (dto.PassengerName.Length > 250)
            return "Passenger name is too long (250 characters max).";

        if (string.IsNullOrWhiteSpace(dto.PhoneNumber))
            return "A contact phone number is required.";
        if (dto.PhoneNumber.Length > 20)
            return "Phone number is too long.";

        if (dto.Email is { Length: > 250 })
            return "Email address is too long.";
        if (dto.Details is { Length: > 2000 })
            return "Additional details are too long (2000 characters max).";

        if (dto.Passengers is < 1 or > 8)
            return "Passengers must be between 1 and 8.";

        if (!dto.Asap)
        {
            if (dto.ScheduledFor == null)
                return "A pickup time is required.";
            // 5-minute grace so a quote taken moments ago doesn't reject on submit.
            if (dto.ScheduledFor.Value.ToUKTime() < DateTime.Now.ToUKTime().AddMinutes(-5))
                return "Pickup time cannot be in the past.";
        }

        if (dto.Quote?.PriceCash is null or <= 0)
            return "A fare quote is required before booking.";

        return null;
    }
}
```

- [ ] **Step 5: Run, verify PASS** — `dotnet test RedTaxi.Tests --filter PublicBookingValidatorTests -v minimal` → 14 PASS.

- [ ] **Step 6: Commit**

```bash
git add src/backend/RedTaxi.Application/DTOs/PublicBooking/ src/backend/RedTaxi.Application/Features/PublicBooking/ src/backend/RedTaxi.Tests/UnitTests/PublicBookingValidatorTests.cs
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "feat(api): public booking DTOs + guest validation"
```

---

### Task 3: CreatePublicBooking handler + PublicBookingController + CORS/rate limits

**Files:**
- Create: `src/backend/RedTaxi.Application/Features/PublicBooking/CreatePublicBooking.cs`
- Create: `src/backend/RedTaxi.API/Controllers/V2/PublicBookingController.cs`
- Modify: `src/backend/RedTaxi.API/Program.cs` (CORS policy ~line 342, rate limiter ~line 187)

- [ ] **Step 1: Write the handler** (modelled line-for-line on `CreateCustomerBookingRequest` — same WebBooking mapping, operator notification, and helpers; differences: identity from payload, cash-only, no CustomerUserId)

```csharp
using System.Net;
using MediatR;
using RedTaxi.Data;
using RedTaxi.Data.Models;
using RedTaxi.Domain;
using RedTaxi.DTOs.PublicBooking;
using RedTaxi.Services;
using Serilog;

namespace RedTaxi.Application.Features.PublicBooking;

/// <summary>
/// Creates a guest booking <b>request</b> (a <see cref="WebBooking"/>) from the
/// embeddable website widget. Anonymous + tenant-keyed: passenger identity comes
/// from the payload, the booking is always cash scope, and it enters the same
/// operator web-booking queue as every other request.
/// </summary>
public static class CreatePublicBooking
{
    public record Command(CreatePublicBookingRequestDto Dto) : IRequest<Result<PublicBookingCreatedDto>>;

    public class Handler : IRequestHandler<Command, Result<PublicBookingCreatedDto>>
    {
        private readonly RedTaxiDbContext _db;
        private readonly UINotificationService _notification;
        private readonly MessagingService _messagingService;

        public Handler(RedTaxiDbContext db, UINotificationService notification, MessagingService messagingService)
        {
            _db = db;
            _notification = notification;
            _messagingService = messagingService;
        }

        public async Task<Result<PublicBookingCreatedDto>> Handle(Command request, CancellationToken ct)
        {
            var log = Log.ForContext("Feature", "CreatePublicBooking");
            var dto = request.Dto;

            try
            {
                var error = PublicBookingValidator.Validate(dto);
                if (error != null)
                {
                    log.Warning("Public booking validation failed: {Error}", error);
                    return Result.Fail<PublicBookingCreatedDto>(error);
                }

                var now = DateTime.Now.ToUKTime();
                var pickupAt = dto.Asap || dto.ScheduledFor == null ? now : dto.ScheduledFor.Value.ToUKTime();

                var job = new WebBooking
                {
                    AccNo = SystemAccounts.Cash,
                    Scope = BookingScope.Cash,
                    PickupDateTime = pickupAt,
                    ArriveBy = false,
                    PickupAddress = Clean(dto.Pickup!.Description),
                    PickupPostCode = Postcode(dto.Pickup.Postcode),
                    DestinationAddress = Clean(dto.Destination!.Description),
                    DestinationPostCode = Postcode(dto.Destination.Postcode),
                    PassengerName = TitleCase(dto.PassengerName),
                    PhoneNumber = dto.PhoneNumber!.Trim(),
                    Email = dto.Email?.Trim() ?? string.Empty,
                    Passengers = dto.Passengers,
                    Details = BuildDetails(dto),
                    Price = dto.Quote!.PriceCash,
                    CreatedOn = now,
                    CreatedBy = "Website Widget",
                    Status = WebBookingStatus.Default,
                    Processed = false
                };

                await _db.WebBookings.AddAsync(job, ct);
                await _db.SaveChangesAsync(ct);

                await NotifyOperator(log, job);

                log.Information("Created public booking request {RequestId} (widget)", job.Id);

                return Result.Ok(new PublicBookingCreatedDto { RequestId = job.Id.ToString(), Status = "pending" });
            }
            catch (Exception ex)
            {
                log.Error(ex, "Failed to create public booking request");
                return Result.Fail<PublicBookingCreatedDto>("An unexpected error occurred while submitting your booking.");
            }
        }

        private async Task NotifyOperator(Serilog.ILogger log, WebBooking job)
        {
            try
            {
                await _notification.WebBookingCreated(job.AccNo);
                await _messagingService.SendBrowserNotification(
                    "WEBSITE BOOKING REQUEST",
                    $"A website visitor has requested a booking for {job.PickupDateTime:dd/MM/yyyy HH:mm}.",
                    "web_booking");
            }
            catch (Exception ex)
            {
                // Operator alerting must never break the customer's booking.
                log.Warning(ex, "Public booking {RequestId} saved but operator notification failed", job.Id);
            }
        }

        private static string Clean(string? value)
        {
            var v = WebUtility.UrlDecode(value ?? string.Empty).Trim().TrimEnd(',').Trim();
            return v.Length > 250 ? v[..250] : v;
        }

        private static string Postcode(string? value)
        {
            var v = (value ?? string.Empty).Trim().ToUpperInvariant();
            return v.Length > 9 ? v[..9] : v;
        }

        private static string? TitleCase(string? name)
        {
            if (string.IsNullOrWhiteSpace(name)) return name;
            return System.Globalization.CultureInfo.CurrentCulture.TextInfo.ToTitleCase(name.ToLower());
        }

        private static string BuildDetails(CreatePublicBookingRequestDto dto)
        {
            var parts = new List<string>();
            if (!string.IsNullOrWhiteSpace(dto.Details)) parts.Add(dto.Details.Trim());
            var vias = dto.Vias?.Where(v => !string.IsNullOrWhiteSpace(v.Description)).Select(v => v.Description!.Trim()).ToList();
            if (vias is { Count: > 0 }) parts.Add($"Via: {string.Join("; ", vias)}");
            parts.Add("Booked via website widget");
            var details = string.Join(". ", parts);
            return details.Length > 2000 ? details[..2000] : details;
        }
    }
}
```

- [ ] **Step 2: Write the controller**

```csharp
using MediatR;
using Microsoft.AspNetCore.Cors;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using RedTaxi.API.Extensions;
using RedTaxi.Application.Features.Address;
using RedTaxi.Application.Features.Pricing;
using RedTaxi.Application.Features.PublicBooking;
using RedTaxi.DTOs.PublicBooking;

namespace RedTaxi.API.Controllers.V2;

/// <summary>
/// Anonymous surface for the embeddable website booking widget. Every route
/// requires a valid X-Tenant-Key (enforced by TenantResolutionMiddleware —
/// no default-tenant fallback) and is cash-only. CORS is open (no credentials)
/// so any tenant website can embed the widget without API config changes.
/// </summary>
[Route("api/v2/public")]
[ApiController]
[ApiExplorerSettings(GroupName = "v2")]
[EnableCors("PublicWidget")]
[EnableRateLimiting("public")]
public class PublicBookingController : ControllerBase
{
    private readonly IMediator _mediator;

    public PublicBookingController(IMediator mediator) => _mediator = mediator;

    // Mirrors the cash branch of POST /api/v2/pricing/quote (same GetCashPrice
    // handler + rounding). Public quotes are always cash — account/school
    // pricing never leaves the authenticated surface.
    [HttpPost("pricing/quote")]
    public async Task<IActionResult> Quote([FromBody] RedTaxi.DTOs.Booking.GetPriceRequestDto obj)
    {
        if (!obj.IsValid)
            return BadRequest(new { success = false, data = (object?)null, errors = new[] { new { code = "INVALID_REQUEST", message = "Invalid data or missing required fields" } } });

        var result = await _mediator.Send(new GetCashPrice.Query(obj.PickupDateTime, obj.Passengers,
            obj.PickupPostcode, obj.DestinationPostcode, obj.ViaPostcodes, obj.PriceFromBase));
        if (!result.Success)
            return StatusCode(500, new { success = false, data = (object?)null, errors = new[] { new { code = "QUOTE_FAILED", message = result.ErrorMessage } } });

        var response = result.Value;
        response.PriceDriver = Math.Round(response.PriceDriver, 2);
        response.PriceAccount = Math.Round(response.PriceAccount, 2);
        response.DeadMileage = Math.Round(response.DeadMileage, 2);

        return Ok(new { success = true, data = response, errors = Array.Empty<object>() });
    }

    // Mirrors POST /api/v2/address/search (same AddressSearch handler).
    [HttpPost("address/search")]
    public async Task<IActionResult> Search([FromBody] AddressController.SearchRequest body)
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

    // Mirrors GET /api/v2/address/resolve (same AddressResolve handler).
    [HttpGet("address/resolve")]
    public async Task<IActionResult> Resolve([FromQuery] string id, [FromQuery] string? sessionToken = null)
    {
        var result = await _mediator.Send(new AddressResolve.Query(id ?? "", sessionToken));
        return result.ToActionResult(400, "RESOLVE_FAILED");
    }

    [HttpPost("bookings/request")]
    [EnableRateLimiting("public-booking")]
    public async Task<IActionResult> CreateRequest([FromBody] CreatePublicBookingRequestDto model)
    {
        var result = await _mediator.Send(new CreatePublicBooking.Command(model));
        return result.ToActionResult("BOOKING_REQUEST_FAILED");
    }
}
```

- [ ] **Step 3: Register CORS policy + rate-limit policies in `Program.cs`**

Extend the existing `AddCors` call (~line 342):

```csharp
builder.Services.AddCors(o =>
{
    o.AddPolicy("MyPolicy", policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });

    // Embeddable booking widget: anonymous endpoints, tenant routed by
    // X-Tenant-Key, so any tenant website may call them — no credentials.
    o.AddPolicy("PublicWidget", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});
```

Extend the existing `AddRateLimiter` call (~line 187) with two policies after `"auth"`:

```csharp
// Widget quote/address traffic (autocomplete is chatty).
options.AddPolicy("public", httpContext =>
    System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
        partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        factory: _ => new System.Threading.RateLimiting.FixedWindowRateLimiterOptions
        {
            PermitLimit = 120,
            Window = TimeSpan.FromMinutes(1),
        }));

// Widget booking creation — strict.
options.AddPolicy("public-booking", httpContext =>
    System.Threading.RateLimiting.RateLimitPartition.GetFixedWindowLimiter(
        partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        factory: _ => new System.Threading.RateLimiting.FixedWindowRateLimiterOptions
        {
            PermitLimit = 10,
            Window = TimeSpan.FromMinutes(1),
        }));
```

Verify middleware order in `Program.cs` (~line 534-548): `app.UseCors(...)` must run BEFORE `TenantResolutionMiddleware` registration so preflights are answered by CORS; if `UseMiddleware<TenantResolutionMiddleware>()` currently precedes `UseCors`, the OPTIONS-skip added in Task 1 covers it anyway — confirm one of the two holds and note which in the commit message.

- [ ] **Step 4: Build + run full test suite**

```
cd src/backend && dotnet build RedTaxi.API -v quiet && dotnet test RedTaxi.Tests -v minimal
```
Expected: build clean, all tests pass (validator tests from Task 2 cover the handler's validation gate; handler DB path is covered by staging contract tests in Task 6).

- [ ] **Step 5: Commit**

```bash
git add src/backend/RedTaxi.Application/Features/PublicBooking/CreatePublicBooking.cs src/backend/RedTaxi.API/Controllers/V2/PublicBookingController.cs src/backend/RedTaxi.API/Program.cs
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "feat(api): anonymous v2 public booking surface (quote, address, guest booking) with open CORS + rate limits"
```

---

### Task 4: Booking widget app (`src/frontend/apps/booking-widget`)

**Files (all new):**
- `src/frontend/apps/booking-widget/package.json`, `vite.config.ts`, `tsconfig.json`
- `src/frontend/apps/booking-widget/index.html` (dev harness)
- `src/frontend/apps/booking-widget/src/main.tsx` (custom element registration)
- `src/frontend/apps/booking-widget/src/api.ts` (API client)
- `src/frontend/apps/booking-widget/src/machine.ts` (state reducer)
- `src/frontend/apps/booking-widget/src/App.tsx` + `src/components/*.tsx`
- `src/frontend/apps/booking-widget/src/styles.css`
- Tests: `src/frontend/apps/booking-widget/src/__tests__/{api,machine}.test.ts`

- [ ] **Step 1: Scaffold the package**

`package.json`:
```json
{
  "name": "@redtaxi/booking-widget",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "tsc --noEmit && vite build",
    "test": "vitest run"
  },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": {
    "@types/react": "^18.3.3",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.1",
    "jsdom": "^24.1.0",
    "typescript": "^5.5.3",
    "vite": "^5.3.3",
    "vitest": "^2.0.3"
  }
}
```

`vite.config.ts` — IIFE lib build, CSS inlined as a string import so it can be injected into the shadow root:
```ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  define: { "process.env.NODE_ENV": JSON.stringify("production") },
  build: {
    lib: {
      entry: "src/main.tsx",
      name: "RedTaxiBooking",
      formats: ["iife"],
      fileName: () => "widget.js",
    },
    outDir: "dist/v1",
  },
  test: { environment: "jsdom" },
});
```
(Import CSS as `import cssText from "./styles.css?inline"` — Vite inlines it; no separate CSS file ships.)

- [ ] **Step 2: Write failing tests for the API client and state machine**

`src/__tests__/api.test.ts`:
```ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { createApiClient, ApiError } from "../api";

const cfg = { apiBase: "https://api.test", tenantKey: "rtk_pub_test" };

describe("api client", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("sends X-Tenant-Key and unwraps the v2 envelope", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ success: true, data: { priceDriver: 12.5 }, errors: [] }), { status: 200 }) as never
    );
    const api = createApiClient(cfg);
    const data = await api.quote({ pickupPostcode: "SP8 4QA", destinationPostcode: "SP7 8JE", pickupDateTime: "2026-07-15T14:30:00", passengers: 2, priceFromBase: false, viaPostcodes: [], accountNo: 9999 });
    expect(data.priceDriver).toBe(12.5);
    const [url, init] = fetchMock.mock.calls[0];
    expect(String(url)).toBe("https://api.test/api/v2/public/pricing/quote");
    expect((init!.headers as Record<string, string>)["X-Tenant-Key"]).toBe("rtk_pub_test");
  });

  it("throws ApiError with the envelope message on success=false", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(JSON.stringify({ success: false, data: null, errors: [{ code: "QUOTE_FAILED", message: "No route" }] }), { status: 500 }) as never
    );
    const api = createApiClient(cfg);
    await expect(api.quote({} as never)).rejects.toThrowError(ApiError);
    await expect(api.quote({} as never)).rejects.toMatchObject({ code: "QUOTE_FAILED" });
  });

  it("throws ApiError(code=NETWORK) on fetch failure", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new TypeError("Failed to fetch"));
    const api = createApiClient(cfg);
    await expect(api.quote({} as never)).rejects.toMatchObject({ code: "NETWORK" });
  });

  it("throws ApiError(code=RATE_LIMITED) on 429", async () => {
    vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response("", { status: 429 }) as never);
    const api = createApiClient(cfg);
    await expect(api.quote({} as never)).rejects.toMatchObject({ code: "RATE_LIMITED" });
  });
});
```

`src/__tests__/machine.test.ts`:
```ts
import { describe, it, expect } from "vitest";
import { initialState, reduce } from "../machine";

const quoted = () =>
  reduce(reduce(initialState, { type: "QUOTE_REQUESTED" }), {
    type: "QUOTE_OK",
    quote: { priceDriver: 20, mileageText: "10 Miles", durationText: "20 Minutes" },
    at: 1000,
  });

describe("booking state machine", () => {
  it("journey -> quoting -> quoted", () => {
    expect(initialState.step).toBe("journey");
    const s1 = reduce(initialState, { type: "QUOTE_REQUESTED" });
    expect(s1.step).toBe("quoting");
    expect(quoted().step).toBe("quoted");
  });

  it("editing journey fields invalidates the quote", () => {
    const s = reduce(quoted(), { type: "JOURNEY_EDITED" });
    expect(s.step).toBe("journey");
    expect(s.quote).toBeNull();
  });

  it("stale quote (>15 min) requires re-quote on submit", () => {
    const s = quoted();
    expect(reduce(s, { type: "SUBMIT_ATTEMPT", at: 1000 + 14 * 60_000 }).step).toBe("details");
    expect(reduce(s, { type: "SUBMIT_ATTEMPT", at: 1000 + 16 * 60_000 }).step).toBe("requoting");
  });

  it("double submit is a no-op while submitting", () => {
    let s = quoted();
    s = reduce(s, { type: "SUBMIT_ATTEMPT", at: 2000 });
    s = reduce(s, { type: "BOOKING_SUBMITTED" });
    expect(s.step).toBe("submitting");
    expect(reduce(s, { type: "BOOKING_SUBMITTED" })).toBe(s);
  });

  it("API failure preserves state and enters degraded mode", () => {
    const s = reduce(reduce(initialState, { type: "QUOTE_REQUESTED" }), { type: "API_FAILED", stage: "quote" });
    expect(s.step).toBe("degraded");
    expect(s.returnTo).toBe("journey");
  });

  it("retry from degraded returns to the prior step", () => {
    const s = reduce(reduce(reduce(initialState, { type: "QUOTE_REQUESTED" }), { type: "API_FAILED", stage: "quote" }), { type: "RETRY" });
    expect(s.step).toBe("journey");
  });

  it("booking success reaches confirmed with the request id", () => {
    let s = quoted();
    s = reduce(s, { type: "SUBMIT_ATTEMPT", at: 2000 });
    s = reduce(s, { type: "BOOKING_SUBMITTED" });
    s = reduce(s, { type: "BOOKING_OK", requestId: "12345" });
    expect(s.step).toBe("confirmed");
    expect(s.requestId).toBe("12345");
  });
});
```

- [ ] **Step 3: Run tests, verify FAIL** — `cd src/frontend/apps/booking-widget && npm install && npm test` → modules missing.

- [ ] **Step 4: Implement `api.ts`**

```ts
export interface WidgetConfig {
  apiBase: string;
  tenantKey: string;
}

export class ApiError extends Error {
  constructor(public code: string, message: string) { super(message); }
}

interface Envelope<T> { success: boolean; data: T; errors: { code: string; message: string }[]; }

export interface QuoteRequest {
  pickupPostcode: string; destinationPostcode: string; viaPostcodes: string[];
  pickupDateTime: string; passengers: number; priceFromBase: boolean; accountNo: number;
}
export interface QuoteResponse { priceDriver: number; mileageText: string; durationText: string; [k: string]: unknown; }
export interface AddressSuggestion { id: string; description: string; [k: string]: unknown; }
export interface ResolvedAddress { description?: string; postcode?: string; lat?: number; lng?: number; [k: string]: unknown; }
export interface BookingRequest {
  pickup: { description: string; postcode: string; lat?: number; lng?: number };
  destination: { description: string; postcode: string; lat?: number; lng?: number };
  vias: never[]; passengers: number; scheduledFor: string | null; asap: boolean;
  passengerName: string; phoneNumber: string; email: string | null; details: string | null;
  quote: { priceCash: number };
}

const TIMEOUT_MS = 15_000;

export function createApiClient(cfg: WidgetConfig) {
  async function call<T>(path: string, init: RequestInit): Promise<T> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), TIMEOUT_MS);
    let res: Response;
    try {
      res = await fetch(`${cfg.apiBase}${path}`, {
        ...init,
        signal: ctrl.signal,
        headers: { "Content-Type": "application/json", "X-Tenant-Key": cfg.tenantKey, ...(init.headers ?? {}) },
      });
    } catch (e) {
      throw new ApiError(e instanceof DOMException && e.name === "AbortError" ? "TIMEOUT" : "NETWORK", "Could not reach the booking service.");
    } finally {
      clearTimeout(timer);
    }
    if (res.status === 429) throw new ApiError("RATE_LIMITED", "Too many requests — please try again shortly.");
    let body: Envelope<T>;
    try { body = await res.json(); } catch { throw new ApiError("BAD_RESPONSE", "Unexpected response from the booking service."); }
    if (!body.success) {
      const err = body.errors?.[0];
      throw new ApiError(err?.code ?? "UNKNOWN", err?.message ?? "The booking service returned an error.");
    }
    return body.data;
  }

  return {
    quote: (req: QuoteRequest) => call<QuoteResponse>("/api/v2/public/pricing/quote", { method: "POST", body: JSON.stringify(req) }),
    searchAddress: (query: string, sessionToken: string) =>
      call<AddressSuggestion[]>("/api/v2/public/address/search", { method: "POST", body: JSON.stringify({ query, sessionToken, limit: 6 }) }),
    resolveAddress: (id: string, sessionToken: string) =>
      call<ResolvedAddress>(`/api/v2/public/address/resolve?id=${encodeURIComponent(id)}&sessionToken=${encodeURIComponent(sessionToken)}`, { method: "GET" }),
    createBooking: (req: BookingRequest) =>
      call<{ requestId: string; status: string }>("/api/v2/public/bookings/request", { method: "POST", body: JSON.stringify(req) }),
  };
}
export type ApiClient = ReturnType<typeof createApiClient>;
```

- [ ] **Step 5: Implement `machine.ts`**

```ts
export type Step = "journey" | "quoting" | "quoted" | "details" | "requoting" | "submitting" | "confirmed" | "degraded";

export interface Quote { priceDriver: number; mileageText: string; durationText: string; }

export interface State {
  step: Step;
  quote: Quote | null;
  quotedAt: number | null;
  requestId: string | null;
  returnTo: Step | null;   // where RETRY goes from degraded
  error: string | null;
}

export type Event =
  | { type: "QUOTE_REQUESTED" }
  | { type: "QUOTE_OK"; quote: Quote; at: number }
  | { type: "JOURNEY_EDITED" }
  | { type: "SUBMIT_ATTEMPT"; at: number }   // from quoted -> details, or stale -> requoting
  | { type: "BOOKING_SUBMITTED" }            // details form submitted
  | { type: "BOOKING_OK"; requestId: string }
  | { type: "API_FAILED"; stage: "quote" | "booking" | "address"; message?: string }
  | { type: "RETRY" }
  | { type: "RESET" };

const QUOTE_TTL_MS = 15 * 60_000;

export const initialState: State = { step: "journey", quote: null, quotedAt: null, requestId: null, returnTo: null, error: null };

export function reduce(s: State, e: Event): State {
  switch (e.type) {
    case "QUOTE_REQUESTED":
      return s.step === "journey" || s.step === "quoted" ? { ...s, step: "quoting", error: null } : s;
    case "QUOTE_OK":
      return { ...s, step: s.step === "requoting" ? "details" : "quoted", quote: e.quote, quotedAt: e.at, error: null };
    case "JOURNEY_EDITED":
      return { ...s, step: "journey", quote: null, quotedAt: null };
    case "SUBMIT_ATTEMPT":
      if (s.step !== "quoted") return s;
      if (s.quotedAt !== null && e.at - s.quotedAt > QUOTE_TTL_MS) return { ...s, step: "requoting" };
      return { ...s, step: "details" };
    case "BOOKING_SUBMITTED":
      return s.step === "details" ? { ...s, step: "submitting" } : s;
    case "BOOKING_OK":
      return { ...s, step: "confirmed", requestId: e.requestId };
    case "API_FAILED": {
      const returnTo: Step = e.stage === "booking" ? "details" : "journey";
      return { ...s, step: "degraded", returnTo, error: e.message ?? null };
    }
    case "RETRY":
      return s.step === "degraded" ? { ...s, step: s.returnTo ?? "journey", error: null } : s;
    case "RESET":
      return initialState;
    default:
      return s;
  }
}
```

- [ ] **Step 6: Run tests, verify PASS** — `npm test` → all green.

- [ ] **Step 7: Implement the custom element (`main.tsx`), App, components, styles**

`main.tsx`:
```tsx
import { createRoot, type Root } from "react-dom/client";
import App from "./App";
import cssText from "./styles.css?inline";

const OBSERVED = ["tenant-key", "api-base", "phone", "mode"] as const;

class RedTaxiBookingElement extends HTMLElement {
  static observedAttributes = [...OBSERVED];
  private root: Root | null = null;
  private mount: HTMLDivElement | null = null;

  connectedCallback() {
    if (!this.shadowRoot) {
      const shadow = this.attachShadow({ mode: "open" });
      const style = document.createElement("style");
      style.textContent = cssText;
      shadow.appendChild(style);
      this.mount = document.createElement("div");
      shadow.appendChild(this.mount);
    }
    this.render();
  }

  attributeChangedCallback() { if (this.mount) this.render(); }
  disconnectedCallback() { this.root?.unmount(); this.root = null; }

  private render() {
    const tenantKey = this.getAttribute("tenant-key") ?? "";
    const apiBase = (this.getAttribute("api-base") ?? "").replace(/\/$/, "");
    const phone = this.getAttribute("phone") ?? "";
    const mode = this.getAttribute("mode") === "compact" ? "compact" : "full";
    if (!this.root) this.root = createRoot(this.mount!);
    this.root.render(
      <App tenantKey={tenantKey} apiBase={apiBase} phone={phone} mode={mode}
           emit={(name, detail) => this.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }))} />
    );
  }
}

if (!customElements.get("redtaxi-booking")) {
  customElements.define("redtaxi-booking", RedTaxiBookingElement);
}
```

`App.tsx` orchestrates: `useReducer(reduce, initialState)` + journey form state (pickup/destination selections, date, time, passengers) + details form state (name/phone/email/notes). Emits `rt:start` on first interaction, `rt:quote` on QUOTE_OK, `rt:booking` on BOOKING_OK, `rt:error` on API_FAILED. Renders per `state.step`:
- `journey`: `<JourneyStep>` — two `<AddressAutocomplete>` (debounced 250ms search via `api.searchAddress`, list of suggestions, on select `api.resolveAddress` → keeps `{description, postcode, lat, lng}`; one `crypto.randomUUID()` sessionToken per lookup session), date input (`min` = today), time select (30-min slots, past slots for today filtered out), passengers 1–8, "Get quote" button (disabled until both addresses resolved + date/time chosen).
- `quoting`/`requoting`: spinner over the journey card.
- `quoted`: `<QuotePanel>` — fare (`£{priceDriver.toFixed(2)}`), mileageText, durationText, "Book this taxi" → `SUBMIT_ATTEMPT`; any edit of journey fields dispatches `JOURNEY_EDITED`.
- `details`: `<DetailsStep>` — name/phone (required, phone pattern `^(\+44|0)\d{9,10}$` after stripping spaces), email (optional, type=email), notes textarea; submit → `BOOKING_SUBMITTED` then `api.createBooking` (button disabled while `submitting`).
- `confirmed`: reference `state.requestId`, "we'll confirm your booking shortly", "Book another" → `RESET`.
- `degraded`: `<CallUsCard phone={phone}>` — message + `tel:` link + "Try again" → `RETRY` (all form state lives in App-level `useState`, so nothing is lost).

If `tenant-key` or `api-base` attribute is missing/empty, render `<CallUsCard>` immediately (misconfiguration must still leave the visitor a path to book).

`compact` mode: same flow, tighter spacing, hides the notes field until details step — controlled by a `data-mode` attribute on the container that CSS targets.

`styles.css` root block (all theme tokens with defaults; components use only these vars):
```css
:host {
  --rt-primary: #d61f26;
  --rt-primary-foreground: #ffffff;
  --rt-surface: #ffffff;
  --rt-text: #1a1a1a;
  --rt-muted: #6b7280;
  --rt-border: #e5e7eb;
  --rt-radius: 12px;
  --rt-font: system-ui, -apple-system, "Segoe UI", sans-serif;
  display: block;
  font-family: var(--rt-font);
  color: var(--rt-text);
}
```
All interactive elements get visible focus states; labels tied to inputs (`htmlFor`); suggestion list is keyboard-navigable (`role="listbox"`, arrow keys, Enter selects).

- [ ] **Step 8: Dev harness `index.html`** (repo root of the app; served by `npm run dev` on a port from the port registry)

```html
<!doctype html>
<html>
  <head><meta charset="utf-8"><title>redtaxi-booking harness</title></head>
  <body style="max-width:480px;margin:2rem auto;">
    <redtaxi-booking
      tenant-key="rtk_pub_CHANGE_ME"
      api-base="https://staging-api.redtaxi.co.uk"
      phone="01747 000000"
      mode="full"></redtaxi-booking>
    <script type="module" src="/src/main.tsx"></script>
    <script>
      document.querySelector("redtaxi-booking").addEventListener("rt:quote", e => console.log("rt:quote", e.detail));
      document.querySelector("redtaxi-booking").addEventListener("rt:booking", e => console.log("rt:booking", e.detail));
    </script>
  </body>
</html>
```

- [ ] **Step 9: Build + verify bundle**

```
npm run build
```
Expected: `dist/v1/widget.js` produced, single file, no separate CSS. Open the harness (`npm run dev`, allocate port via `O:\RBS-OS\scripts\port-alloc.ps1 alloc -Project "red-taxi" -App booking-widget -Stack vite`) and manually walk the flow once against staging (after Task 6 deploys the API; before that the degraded call-us card should appear — which itself verifies the fallback).

- [ ] **Step 10: Commit**

```bash
git add src/frontend/apps/booking-widget
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "feat(widget): embeddable redtaxi-booking web component (quote -> guest booking, themeable, degradable)"
```

---

### Task 5: Staging deploy + First Taxis tenant key + contract tests

Staging runs on this machine (i9) per `docs/staging-environment.md`; deploy via `staging/rebuild.ps1`, control DB is local Postgres `redtaxi_control`.

- [ ] **Step 1: Apply the control DB migration**

```powershell
psql -h localhost -U postgres -d redtaxi_control -f src/backend/scripts/control-db/2026-07-10-add-organization-public-key.sql
```
(Password from the staging launcher config / credentials.env — check `staging/start-api.cmd` conventions; never commit it.)

- [ ] **Step 2: Inspect organizations, decide First Taxis tenant**

```sql
SELECT id, name, status, database_url IS NOT NULL AS has_db, public_key FROM organization;
```
- If a First Taxis org exists → use it.
- If not: provision one the same way existing orgs were created (copy the default org's row pattern: new `id` like `org_<ulid>`, `name='First Taxis'`, `status='active'`, `database_url` pointing at a freshly created tenant DB cloned from the tenant schema). Check `src/backend/RedTaxi.DataMigration` and the saas-admin provisioning path for the canonical mechanism before hand-rolling; if provisioning is heavier than the demo needs, fall back to issuing the key against the staging default tenant org **explicitly** (documented in the PR as demo-only) — the isolation edge-case test then uses a second dummy org.

- [ ] **Step 3: Issue the key**

```sql
UPDATE organization SET public_key = 'rtk_pub_' || encode(gen_random_bytes(24), 'hex') WHERE id = '<first-taxis-org-id>' RETURNING public_key;
```
Record the returned key for widget config (env var, not committed).

- [ ] **Step 4: Deploy the API to staging** — `staging/rebuild.ps1`, then verify `https://staging-api.redtaxi.co.uk/health` returns healthy.

- [ ] **Step 5: Contract-test the four endpoints against staging** (script `src/backend/scripts/contract-test-public-api.ps1`, committed):

```powershell
param([Parameter(Mandatory)][string]$TenantKey, [string]$ApiBase = "https://staging-api.redtaxi.co.uk")
$H = @{ "X-Tenant-Key" = $TenantKey; "Content-Type" = "application/json" }
$fail = 0
function Check($name, $cond) { if ($cond) { Write-Host "PASS $name" } else { Write-Host "FAIL $name"; $script:fail++ } }

# 1. quote
$q = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/pricing/quote" -Headers $H -Body (@{
  pickupPostcode = "SP8 4QA"; destinationPostcode = "SP7 8JE"; viaPostcodes = @();
  pickupDateTime = (Get-Date).AddHours(3).ToString("s"); passengers = 2; priceFromBase = $false; accountNo = 9999 } | ConvertTo-Json)
Check "quote.success" $q.success
Check "quote.priceDriver numeric" ($q.data.priceDriver -is [double] -or $q.data.priceDriver -is [decimal] -or $q.data.priceDriver -is [int])
Check "quote.mileageText present" (-not [string]::IsNullOrEmpty($q.data.mileageText))

# 2. address search
$s = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/address/search" -Headers $H -Body (@{ query = "High Street, Gillingham"; sessionToken = [guid]::NewGuid().ToString(); limit = 5 } | ConvertTo-Json)
Check "search.success" $s.success
Check "search.has results" ($s.data.Count -gt 0)

# 3. resolve first suggestion
$tok = [guid]::NewGuid().ToString()
$s2 = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/address/search" -Headers $H -Body (@{ query = "High Street, Gillingham"; sessionToken = $tok; limit = 5 } | ConvertTo-Json)
$r = Invoke-RestMethod -Method Get -Uri "$ApiBase/api/v2/public/address/resolve?id=$([uri]::EscapeDataString($s2.data[0].id))&sessionToken=$tok" -Headers $H
Check "resolve.success" $r.success
Check "resolve.postcode present" (-not [string]::IsNullOrEmpty($r.data.postcode))

# 4. booking create + negative cases
$b = Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/bookings/request" -Headers $H -Body (@{
  pickup = @{ description = "Contract Test Pickup, Gillingham"; postcode = "SP8 4QA" }
  destination = @{ description = "Contract Test Dropoff, Shaftesbury"; postcode = "SP7 8JE" }
  vias = @(); passengers = 2; scheduledFor = (Get-Date).AddHours(3).ToString("s"); asap = $false
  passengerName = "Contract Test"; phoneNumber = "07700900123"; email = "test@example.com"
  details = "CONTRACT TEST - do not dispatch"; quote = @{ priceCash = $q.data.priceDriver } } | ConvertTo-Json -Depth 5)
Check "booking.success" $b.success
Check "booking.requestId" (-not [string]::IsNullOrEmpty($b.data.requestId))

# 5. missing key -> 401; bad key -> 401
try { Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/pricing/quote" -Body "{}" -ContentType "application/json"; Check "missing key 401" $false }
catch { Check "missing key 401" ($_.Exception.Response.StatusCode.value__ -eq 401) }
try { Invoke-RestMethod -Method Post -Uri "$ApiBase/api/v2/public/pricing/quote" -Headers @{ "X-Tenant-Key" = "rtk_pub_bogus"; "Content-Type" = "application/json" } -Body "{}"; Check "bad key 401" $false }
catch { Check "bad key 401" ($_.Exception.Response.StatusCode.value__ -eq 401) }

if ($fail -gt 0) { Write-Error "$fail contract check(s) failed"; exit 1 } else { Write-Host "ALL CONTRACT CHECKS PASSED" }
```
Run: `powershell -File src/backend/scripts/contract-test-public-api.ps1 -TenantKey <key>` → ALL PASS. Delete/reject the contract-test booking in staging dispatch afterwards.

- [ ] **Step 6: Commit the contract script**

```bash
git add src/backend/scripts/contract-test-public-api.ps1
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "test(api): staging contract checks for the v2 public booking surface"
```

---

### Task 6: First Taxis integration (first-taxis worktree)

**Files:**
- Create: `public/redtaxi-widget/v1/widget.js` (built artifact copied from RedTaxi worktree `dist/v1/widget.js` — demo hosting; production host `widget.redtaxi.co.uk` is a rollout step, noted in README)
- Create: `public/redtaxi-widget/README.md` (provenance: built from red-taxi `feature/public-booking-widget` `src/frontend/apps/booking-widget`; do not hand-edit)
- Create: `src/components/forms/RedTaxiBooking.tsx` (React wrapper for the custom element)
- Modify: `src/components/forms/QuoteForm.tsx` (keep card chrome; body becomes the widget, compact)
- Modify: `src/pages/BookOnline.tsx` (form column becomes the widget, full; sidebar unchanged)
- Modify: `src/index.css` (theme mapping), `src/vite-env.d.ts` (JSX typing), `.env` / `.env.example` (widget config), `index.html` (script tag)

- [ ] **Step 1: Copy the built bundle + README, add script tag to `index.html`:**

```html
<script src="/redtaxi-widget/v1/widget.js" defer></script>
```

- [ ] **Step 2: Env config** — `.env.example` (real values in `.env`, staging key from Task 5):

```
VITE_RT_TENANT_KEY=rtk_pub_xxx
VITE_RT_API_BASE=https://staging-api.redtaxi.co.uk
```

- [ ] **Step 3: JSX typing in `vite-env.d.ts`:**

```ts
declare namespace JSX {
  interface IntrinsicElements {
    "redtaxi-booking": React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement> & {
      "tenant-key"?: string; "api-base"?: string; phone?: string; mode?: "compact" | "full";
    };
  }
}
```

- [ ] **Step 4: Wrapper component `RedTaxiBooking.tsx`** (attaches GTM listeners once):

```tsx
import { useEffect, useRef } from "react";
import { BUSINESS } from "@/lib/constants";
import { trackFormSubmit, trackQuoteFormStart } from "@/lib/gtm";

export function RedTaxiBooking({ mode }: { mode: "compact" | "full" }) {
  const ref = useRef<HTMLElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const onStart = () => trackQuoteFormStart();
    const onBooking = (e: Event) =>
      trackFormSubmit(mode === "compact" ? "quote_form" : "booking_form", {
        requestId: (e as CustomEvent).detail?.requestId,
      });
    el.addEventListener("rt:start", onStart);
    el.addEventListener("rt:booking", onBooking);
    return () => { el.removeEventListener("rt:start", onStart); el.removeEventListener("rt:booking", onBooking); };
  }, [mode]);

  return (
    <redtaxi-booking
      ref={ref as never}
      tenant-key={import.meta.env.VITE_RT_TENANT_KEY}
      api-base={import.meta.env.VITE_RT_API_BASE}
      phone={BUSINESS.phone}
      mode={mode}
    />
  );
}
```

- [ ] **Step 5: Swap into `QuoteForm.tsx`** — keep the existing header + trust line markup; replace the `<form>...</form>` block with `<RedTaxiBooking mode="compact" />`. Remove now-unused imports/state.

- [ ] **Step 6: Swap into `BookOnline.tsx`** — replace the entire `<form>...</form>` inside the card with `<RedTaxiBooking mode="full" />`; delete the dead `handleSubmit`/`formData`/`timeSlots` code; sidebar stays.

- [ ] **Step 7: Theme mapping in `index.css`** (site tokens → widget vars; read actual values from the site's existing CSS custom properties):

```css
redtaxi-booking {
  --rt-primary: hsl(var(--primary));
  --rt-primary-foreground: hsl(var(--primary-foreground));
  --rt-surface: hsl(var(--card));
  --rt-text: hsl(var(--foreground));
  --rt-muted: hsl(var(--muted-foreground));
  --rt-border: hsl(var(--border));
  --rt-radius: var(--radius);
  --rt-font: inherit;
}
```

- [ ] **Step 8: Verify locally** — `npm run dev` (port via registry, bind 0.0.0.0), open `http://i9:<port>`: home hero shows working compact widget, `/book-online` shows full widget, quote against staging returns a real fare, GTM events fire (check dataLayer in console). Run `npx tsc --noEmit && npm test && npm run build`.

- [ ] **Step 9: Commit**

```bash
git add index.html public/redtaxi-widget src/components/forms/RedTaxiBooking.tsx src/components/forms/QuoteForm.tsx src/pages/BookOnline.tsx src/index.css src/vite-env.d.ts .env.example
git commit --author="Peter Farrell <peter@redbananastudios.com>" -m "feat: live quote + booking via Red Taxi public widget (staging)"
```

---

### Task 7: End-to-end + edge cases (Playwright), review, PRs

**Files:**
- Create (first-taxis): `tests/e2e/booking-widget.spec.ts`, `playwright.config.ts`; devDep `@playwright/test`

- [ ] **Step 1: Playwright config** — baseURL from env (`E2E_BASE_URL`, default the local dev server), one chromium project, `webServer` starting `npm run dev`.

- [ ] **Step 2: e2e spec** (runs against staging API through the real page):

```ts
import { test, expect } from "@playwright/test";

// Shadow-DOM piercing: Playwright locators do this natively.
const widget = (page) => page.locator("redtaxi-booking");

test("full booking loop against staging", async ({ page }) => {
  await page.goto("/book-online");
  const w = widget(page);
  await w.getByLabel(/pickup/i).fill("High Street, Gillingham");
  await w.getByRole("option").first().click();
  await w.getByLabel(/destination/i).fill("Bell Street, Shaftesbury");
  await w.getByRole("option").first().click();
  await w.getByLabel(/date/i).fill(dateTomorrow());
  await w.getByLabel(/time/i).selectOption("14:30");
  await w.getByRole("button", { name: /get quote|quote/i }).click();
  await expect(w.getByText(/£\d+\.\d{2}/)).toBeVisible({ timeout: 20_000 });
  await w.getByRole("button", { name: /book this taxi/i }).click();
  await w.getByLabel(/name/i).fill("E2E Test");
  await w.getByLabel(/phone/i).fill("07700900123");
  await w.getByLabel(/notes|details/i).fill("E2E TEST - do not dispatch");
  await w.getByRole("button", { name: /request booking|confirm/i }).click();
  await expect(w.getByText(/request received|we'll confirm/i)).toBeVisible({ timeout: 20_000 });
  const ref = await w.getByTestId("rt-request-id").textContent();
  expect(ref).toMatch(/\d+/);
  // Server-side verification happens in step 3 using this reference.
  console.log("BOOKING_REF=" + ref);
});

test("degrades to call-us card when API unreachable", async ({ page }) => {
  await page.route("**/api/v2/public/**", r => r.abort());
  await page.goto("/book-online");
  const w = widget(page);
  await w.getByLabel(/pickup/i).fill("High Street, Gillingham");
  await expect(w.getByText(/call us/i)).toBeVisible({ timeout: 20_000 });
  await expect(w.getByRole("link", { name: /01747|0\d{3,}/ })).toBeVisible();
});

test("double submit creates one booking", async ({ page }) => {
  // drive to details step (same helper as test 1), then:
  // await Promise.all([details submit click, details submit click]);
  // assert exactly one POST to /bookings/request via page.on('request') counter
});

function dateTomorrow() { const d = new Date(Date.now() + 86_400_000); return d.toISOString().slice(0, 10); }
```
Fill in the double-submit test with the shared journey helper extracted from test 1 (helper `driveToDetails(page)`), counting `request` events for `/bookings/request` and asserting `count === 1`.

- [ ] **Step 3: Server-side verification** — with a staging dev token (`GET https://staging-api.redtaxi.co.uk/dev/token?user=Peter`):

```powershell
$token = (Invoke-RestMethod "https://staging-api.redtaxi.co.uk/dev/token?user=Peter").token
$bookings = Invoke-RestMethod -Uri "https://staging-api.redtaxi.co.uk/api/v2/web-bookings" -Headers @{ Authorization = "Bearer $token" } -Method Post -Body '{}' -ContentType "application/json"
```
Assert the e2e booking reference is present, `passengerName = "E2e Test"`, price equals the quoted fare, tenant is First Taxis. Then accept it in staging dispatch UI (`https://staging-app.redtaxi.co.uk`) and confirm no downstream error. Reject/clean up test bookings afterwards.
(Adjust the list call to the actual v2 web-bookings list contract — check `Controllers/V2/WebBookingsController.cs` for the exact route/body when writing the script.)

- [ ] **Step 4: API-level edge cases** — extend `contract-test-public-api.ps1` with: invalid postcode (`ZZ99 9ZZ` → quote fails cleanly with envelope error, not 500), past `scheduledFor` (→ `success=false`, "past" message), `passengers: 9` (→ validation error), 300-char name (→ validation error), `<script>alert(1)</script>` in details (→ booking succeeds, stored inert — verify via the web-bookings list that it round-trips as text), pickup == destination (→ validation error). Each asserts the envelope shape.

- [ ] **Step 5: Run everything** — backend `dotnet test`, widget `npm test`, first-taxis `npx tsc --noEmit && npm test && npm run build`, contract script, Playwright suite. All green.

- [ ] **Step 6: Code review** — dispatch the code-reviewer agent over both diffs (RedTaxi worktree diff vs `origin/dev`, first-taxis branch diff). Resolve every issue raised.

- [ ] **Step 7: Ship**

```bash
# RedTaxi: push branch, open PR to dev
git push -u origin feature/public-booking-widget
gh pr create --repo redbananastudios/red-taxi --base dev --title "Public booking widget: v2 anonymous tenant-keyed surface + embeddable web component" --body "<summary + test evidence>"

# first-taxis: push branch (base main)
git push -u origin claude/redtaxi-quote-form-api-503eb9
gh pr create --base main --title "Wire quote/booking forms to Red Taxi staging via embeddable widget" --body "<summary + e2e evidence>"
```

---

## Self-review notes

- Spec coverage: middleware/key (Task 1), DTOs+validation (Task 2), endpoints+CORS+rate limits (Task 3), widget+theming+events+fallback (Task 4), staging+key+contract tests (Task 5), First Taxis+GTM (Task 6), e2e+edge cases+review+PRs (Task 7). Widget bundle production hosting (widget.redtaxi.co.uk) deliberately deferred to rollout — demo serves from first-taxis `public/`.
- Type consistency: `CustomerPlaceDto` reused across customer + public DTOs; widget `BookingRequest` matches `CreatePublicBookingRequestDto` (camelCase JSON binds case-insensitively); envelope handling identical across endpoints.
- Known runtime decision points (flagged, not placeholders): First Taxis org provisioning path (Task 5 Step 2 has both branches), exact v2 web-bookings list contract (Task 7 Step 3 names the file to check).
