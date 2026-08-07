# Backend Standards

Conventions for all backend code in the Red Taxi monorepo.
These rules apply to all new code and any code being modified.

---

## Handler Return Types

All MediatR handlers **must** return `Result<T>` (queries/commands with data) or `Result` (commands with no data).

```csharp
// Query handler — returns Result<T>
public class GetAllAccounts
{
    public record Query() : IRequest<Result<List<AccountDto>>>;

    public class Handler : IRequestHandler<Query, Result<List<AccountDto>>>
    {
        public async Task<Result<List<AccountDto>>> Handle(Query request, CancellationToken ct)
        {
            try
            {
                var data = await _service.GetAll();
                return Result.Ok(data);
            }
            catch (Exception ex)
            {
                _log.Error(ex, "Failed to get accounts");
                return Result.Fail<List<AccountDto>>("Failed to get accounts");
            }
        }
    }
}

// Command handler — returns Result
public class DeleteAccount
{
    public record Command(int Id) : IRequest<Result>;

    public class Handler : IRequestHandler<Command, Result>
    {
        public async Task<Result> Handle(Command request, CancellationToken ct)
        {
            try
            {
                await _service.Delete(request.Id);
                return Result.Ok();
            }
            catch (Exception ex)
            {
                _log.Error(ex, "Failed to delete account {Id}", request.Id);
                return Result.Fail("Failed to delete account");
            }
        }
    }
}
```

**Legacy handlers** returning raw `List<T>`, `void`, or DTOs exist in Reporting, Dispatch, Availability, UserProfile, and other feature areas. These will be migrated to `Result<T>` over time. Do not add new handlers with raw return types.

---

## V2 API Envelope

Every v2 endpoint **must** return the standard envelope with all three fields:

```json
// Success
{ "success": true,  "data": <T>,   "errors": [] }

// Failure
{ "success": false, "data": null,  "errors": [{ "code": "ERROR_CODE", "message": "Human-readable message" }] }
```

### Using ToActionResult()

When a handler returns `Result<T>`, use the `ToActionResult()` extension from `RedTaxi.API.Extensions.ResultExtensions`:

```csharp
// Default: 200 OK on success, 400 Bad Request on failure
return (await _mediator.Send(new GetAccount.Query(id))).ToActionResult("ACCOUNT_NOT_FOUND");

// Custom failure status code (404, 429, 423, etc.)
return result.ToActionResult(404, "ACCOUNT_NOT_FOUND");
```

When a handler returns a raw type (legacy), construct the envelope inline:

```csharp
var data = await _mediator.Send(new SomeQuery());
return Ok(new { success = true, data, errors = Array.Empty<object>() });
```

Do **not** mix envelope styles within a single controller.

---

## Error Codes

- Format: `UPPER_SNAKE_CASE`
- Domain-prefixed: `BOOKING_NOT_FOUND`, `DRIVER_LIMIT_REACHED`, `TARIFF_UPDATE_FAILED`
- Generic fallback: `OPERATION_FAILED`
- Always in an `errors` array, never a bare `error` string

---

## Authentication

- **Class-level `[Authorize]`** on all v2 controllers by default.
- Use `[AllowAnonymous]` on specific methods that must be public (login, register, webhooks, public pricing, cron-triggered endpoints).
- Never leave endpoints unprotected by omission.

**Exceptions** (intentionally public):
- `DeliveryStatusController` — webhook callbacks from external systems
- `PricingController` — public pricing data
- `UserProfileV2Controller` — Login/Register/RefreshToken are public; other methods use per-method `[Authorize]`

---

## Tenancy

- **Never** hardcode a tenant ID, org ID, or tenant name.
- Resolve tenant context from `HttpContext.Items["TenantOrgId"]`.
- If tenant context is missing, return 401 — do **not** fall back to a default tenant.
- All tenant-specific config belongs in the `TenantConfig` table via `ITenantConfigService`.

---

## Logging

Every handler must log:
- **Success**: `Information` level with relevant IDs
- **Failure**: `Warning` or `Error` level with error details

```csharp
private static readonly Serilog.ILogger Log = Serilog.Log.ForContext<Handler>();

// On success
Log.Information("[{Feature}] Retrieved {Count} accounts for tenant {TenantId}", "GetAllAccounts", data.Count, tenantId);

// On failure
Log.Warning("[{Feature}] Failed to retrieve accounts: {Error}", "GetAllAccounts", ex.Message);
```

---

## Controller Rules

Controllers are **routing only**. They must not contain:
- Business logic or calculations
- Data filtering, sorting, or grouping
- Direct database queries (use MediatR handlers)
- Conditional logic beyond auth/envelope construction

Controllers accept HTTP requests, resolve the current user/tenant from context, and call `_mediator.Send()`.

---

## Class Size

Maximum **300 lines** per class. If a controller or handler exceeds this, split it.

---

## Naming

- Handler files match use case: `GetDriverExpirys.cs`, `CreateBooking.cs`
- One handler per file
- Static class wrapper with nested `Query`/`Command` record and `Handler` class
- Feature folders in `RedTaxi.Application/Features/{FeatureName}/`

---

## V1 Controllers

V1 controllers are **frozen**. No route changes, no response shape changes.

When a handler is migrated to `Result<T>`, update the v1 controller to unwrap:
```csharp
var result = await _mediator.Send(new SomeQuery());
return result.Success ? Ok(result.Value) : BadRequest(result.ErrorMessage);
```

The v1 API response body must remain identical to consumers.
