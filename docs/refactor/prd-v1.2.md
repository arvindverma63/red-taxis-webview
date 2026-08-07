# Red Taxi — API Refactoring & SaaS Transformation PRD

**Version:** 1.2  
**Status:** Locked  
**Platform:** Red Taxi | **Initial Tenant:** Ace Taxis  
**Stack:** .NET 8 · EF Core 8 · PostgreSQL · MediatR · Serilog  
**Author:** Red Banana Studios

> This document is locked. No further scope may be added. New requirements belong in a subsequent PRD.

---

## 1. Objective

Refactor the existing Ace Taxis API from a two-project monolithic god-class architecture
into a clean, six-project feature-sliced, AI-maintainable structure — without downtime
and with continuous test coverage.

This is a **live system refactor**. The production API remains operational throughout.
No big-bang rewrites. No logic changes. No route changes.

### Goals

- Eliminate god services (`BookingService` alone is 2,100+ lines)
- Restructure into six clearly-scoped projects
- Add structured logging and global error handling throughout
- Migrate to `Feature/Xxxx` vertical slice structure with MediatR
- Expose clean v2 endpoints alongside each migrated feature
- Prepare the data layer for multi-tenancy using EF Core global query filters
- Remove incorrectly-used interfaces and redundant classes
- Make the codebase AI-navigable — one handler per use case, one file per use case
- Test every feature before and after each refactor step

### Out of Scope — This PRD

The following items are explicitly excluded. Anything not listed here belongs in a new PRD
that follows this one.

- New feature development
- UI or frontend changes
- New third-party integrations
- SaaS onboarding portal
- AI features
- Performance optimisation work

---

## 2. Current System Problems

| Problem | Impact | Fix |
|---|---|---|
| Two-project monolith | No separation of concerns | Split into six scoped projects |
| Business logic in controllers | Untestable, violates SRP | Move all logic to MediatR handlers |
| God services (2000+ lines) | High change risk, no isolation | Feature/Xxxx slice per use case |
| Hardcoded Ace-specific rules | Blocks multi-tenancy | Tenant config table + ITenantContext |
| No structured logging | Blind in production | Serilog with TenantId + Feature context |
| No global error handling | Inconsistent error responses | ProblemDetails middleware |
| No automated tests | Refactoring is dangerous | WebApplicationFactory per feature |
| Single-tenant design | Cannot onboard new operators | EF Core global query filters on TenantId |
| Bad interfaces | IXxx with one impl, never mocked | Remove unless multiple impls or test-injected |
| Redundant classes | Dead code, maintenance noise | Remove — identified during Phase 0 baseline |

---

## 3. Target Project Structure

```
RedTaxi.API              Controllers, middleware, DI registration, Scalar (/scalar/v1)
RedTaxi.Application      Features, handlers, commands, queries (MediatR)
RedTaxi.Domain           Entities, domain events, enums, value objects
RedTaxi.Data             DbContext, EF Core configuration, migrations, seeds
RedTaxi.Infrastructure   External integrations ONLY — SMS, payments, maps, email
RedTaxi.Shared           Result<T>, extensions, guard clauses — zero dependencies on other RT projects
```

### Dependency Rules

`API` → `Application` → `Domain`  
`API` → `Data` (for DI registration only)  
`Infrastructure` → `Domain`  
`Data` → `Domain`  
`Shared` → nothing (no Red Taxi project dependencies)

### Why RedTaxi.Data Is Separate

EF Core and its DbContext do not belong in Infrastructure. Infrastructure owns
external system concerns — calling an API, sending an SMS, charging a card.
The database is an internal persistence concern. Separating it means Infrastructure
is purely outbound integrations, and Data is purely persistence. Migrations live
in `RedTaxi.Data` alongside the DbContext that owns them.

### Why RedTaxi.Shared Exists

Common primitives like `Result<T>`, `PagedList<T>`, guard clauses, and extension
methods are needed across multiple projects. They cannot live in Application or Domain
without creating circular dependencies. Shared solves this cleanly — but it must
remain dependency-free. If a class in Shared needs to reference Application or Domain,
it is in the wrong project.

---

## 4. Naming & Cleanup Rules

### Class Renaming Principles

Names must describe what the class *does*, not what it *is*.
A class called `BookingManager` tells you nothing — `CreateBooking.Handler` tells you exactly.
The following patterns are unacceptable and must be renamed during Phase 0:

- `XxxManager` — rename to the specific use case it handles
- `XxxHelper` — extract logic into appropriate handlers or static utilities
- `XxxProcessor` — rename to describe the specific operation
- `XxxService` — these become `Feature/Xxxx` handlers in Phase 3; flag during Phase 0
- `XxxUtil` or `XxxUtils` — move to `RedTaxi.Shared` as extension methods or static classes

Renaming happens in **Phase 0 only**, as a single dedicated commit before any logic moves.
This prevents rename noise polluting the logical refactor commits.

### Interface Removal Rules

An interface is only justified if one of the following is true:

1. It has more than one implementation
2. It is injected in tests and replaced with a test double

If neither is true, delete the interface and reference the concrete class directly.
The classic offender is `IBookingService` backed only by `BookingService` with no
test injection — this adds indirection with zero benefit.

### Redundant Class Removal Rules

A class is redundant if it is never instantiated, never referenced, or entirely
superseded by another class. Identify all of these during Phase 0 via the baseline
inventory. Mark them with `// [REMOVE]` first, ship one commit to confirm nothing
breaks, then delete in the next commit.

---

## 5. API Versioning

v1 and v2 run in parallel. Critically, **both versions route to the same handler** —
there is no duplicated logic. A bug fix applied to the handler fixes both versions
simultaneously.

```csharp
// v1 — legacy route, untouched, operators still on this
app.MapGroup("/api/v1").MapBookingEndpointsV1();

// v2 — added when the feature slice is created in Phase 3
app.MapGroup("/api/v2").MapBookingEndpointsV2();
```

| Route | Status | Purpose |
|---|---|---|
| `/api/v1/bookings` | Maintained | Existing frontend — behaviour identical |
| `/api/v2/bookings` | New (Phase 3) | Clean handler, typed responses, consistent envelope |

v1 is retired per endpoint only once the frontend confirms it has migrated off it.
v1 routes are **never modified** — only retired.

### v2 Response Envelope

All v2 endpoints return a consistent shape:

```json
{
  "success": true,
  "data": { },
  "errors": []
}
```

Error responses:

```json
{
  "success": false,
  "data": null,
  "errors": [{ "code": "BOOKING_NOT_FOUND", "message": "Booking not found" }]
}
```

---

## 6. Handler Pattern

Each use case is a single self-contained file. No fat service classes. The filename
matches the use case name exactly.

```csharp
public static class CreateBooking
{
    public record Command(Guid TenantId, string Pickup, ...) : IRequest<Result<BookingId>>;

    public class Handler : IRequestHandler<Command, Result<BookingId>>
    {
        public async Task<Result<BookingId>> Handle(Command cmd, CancellationToken ct)
        {
            // Pure business logic only.
            // No direct messaging calls — raise domain events instead.
        }
    }
}
```

Each feature folder must contain a `README.md` with: what the feature does,
input fields, output fields, domain events raised, and which test file covers it.

---

## 7. Logging & Error Handling

### Global Exception Middleware

```csharp
app.UseExceptionHandler(b => b.Run(async ctx =>
{
    var ex = ctx.Features.Get<IExceptionHandlerFeature>()?.Error;
    Log.Error(ex, "Unhandled on {Method} {Path}", ctx.Request.Method, ctx.Request.Path);
    ctx.Response.ContentType = "application/problem+json";
    ctx.Response.StatusCode = 500;
    await ctx.Response.WriteAsJsonAsync(new ProblemDetails { Status = 500, Detail = ex?.Message });
}));
```

### Structured Log Standard

```csharp
Log.ForContext("Feature", "CreateBooking")
   .ForContext("TenantId", command.TenantId)
   .Information("Booking created {BookingRef}", booking.Ref);
```

| Level | When |
|---|---|
| Information | Normal operations — booking created, driver allocated |
| Warning | Expected failures — not found, validation rejected |
| Error | Unexpected — exception thrown, external call failed |

---

## 8. Multi-Tenancy Preparation

### ITenantContext

Resolved from JWT claim on every request. Injected into all handlers.

```csharp
public interface ITenantContext
{
    Guid TenantId { get; }
    string TenantSlug { get; }
}
```

### EF Core Global Query Filters

Applied once in `RedTaxi.Data`. All queries are automatically scoped to the current tenant.

```csharp
modelBuilder.Entity<Booking>()
    .HasQueryFilter(b => b.TenantId == _tenantContext.TenantId);
```

`IgnoreQueryFilters()` is permitted only in admin handlers with an explicit comment explaining why.

### TenantConfig Table

Replaces all hardcoded Ace-specific logic.

| Config Key | Example | Purpose |
|---|---|---|
| DefaultTariffId | ace-standard | Base pricing tariff |
| SmsGateway | twilio | SMS provider |
| PaymentProvider | revolut | Payment link provider |
| DispatchMode | manual | manual \| auto \| hybrid |

---

## 9. Testing Strategy

Write an integration test covering the **current behaviour** before extracting any logic.
That test is the regression guard — if it fails after the move, the move is wrong.

```csharp
public class ApiFixture : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder b)
        => b.UseEnvironment("Testing");
}
```

| Phase | Test Requirement |
|---|---|
| Phase 1 | Error responses return ProblemDetails with correct status codes |
| Phase 2 | Existing endpoint behaviour unchanged — same input, same output |
| Phase 3 | v1 and v2 both pass the same test; handler tested in isolation |
| Phase 4 | Tenant A cannot access Tenant B data |

---

## 10. Refactoring Phases

> All phases run against the live system. Test coverage required before each phase progresses. No phase starts until the previous phase gate is passed.

### Phase 0 — Baseline & Cleanup (Days 1–3, no logic changes) ✓ COMPLETE

1. List every endpoint — method, route, controller, service method it calls
2. Document every class and interface — one-liner per class describing its purpose
3. Tag god service logic: `// [PRICING]` `// [MESSAGING]` `// [DISPATCH]` `// [ACE-SPECIFIC]`
4. Identify bad interface names, redundant classes — mark with `// [RENAME]` or `// [REMOVE]`
5. Apply all renames in one dedicated commit — verify compilation and tests pass
6. Remove dead interfaces and redundant classes in a second commit — verify again
7. This baseline becomes the regression contract for all subsequent phases

### Phase 1 — Stabilise In Place (Days 3–5, zero logic changes) ✓ COMPLETE

1. Add Serilog with structured output (console + file sink)
2. Add global ProblemDetails exception middleware
3. Add request/response logging middleware (method, path, duration, status)
4. Add `ILogger<T>` everywhere it is missing
5. Add Scalar at `/scalar/v1`
6. Add `ApiFixture` and a smoke test per major feature area

### Phase 2 — Project Split & Extract (Days 5–10) ✓ COMPLETE

1. Create the six-project solution structure
2. Move DbContext, EF config, and migrations into `RedTaxi.Data`
3. Move external integration classes into `RedTaxi.Infrastructure`
4. Move `Result<T>` and shared utilities into `RedTaxi.Shared`
5. Extract tagged logic from god services into private static methods — no class moves yet
6. Replace all `// [ACE-SPECIFIC]` hardcodes with `ITenantConfig` lookups
7. Verify entire test suite still passes after each move

### Phase 3 — Feature Slices + v2 Endpoints (Weeks 2–4) ✓ COMPLETE

> **Status:** 241 handlers across 16 feature areas. All controllers wired to MediatR.
> Services remain as business logic engine — handlers are thin wrappers that delegate.

Feature migration order: Pricing → Messaging → Dispatch → Bookings → Accounts

For each feature:
1. Create `Features/Xxxx/UseCaseName.cs` with Command/Query and Handler
2. Add `/api/v2` route pointing to the new handler
3. Update v1 route to delegate to the same handler
4. Write integration test — run against both v1 and v2
5. Once tests pass, delete the old service method
6. Update `README.md` in the feature folder
7. Repeat until all `XxxxService` classes are gone

### Phase 4 — Multi-Tenancy (Days after Phase 3) — DEFERRED

1. Add `Tenants` and `TenantConfig` tables with migrations in `RedTaxi.Data`
2. Implement `ITenantContext` resolved from JWT in `RedTaxi.Infrastructure`
3. Add EF Core global query filters on all tenant-scoped entities
4. Migrate all remaining Ace-specific hardcodes to `TenantConfig` rows
5. Write cross-tenant isolation tests — verify Tenant A cannot read Tenant B data

---

## 11. Forbidden Patterns

These must never appear in the refactored codebase. Any AI agent working on this
codebase must refuse to introduce these patterns.

| Rule | Reason |
|---|---|
| Business logic in controllers | Controllers are routing only |
| IMediator.Send called inside a Handler | Handlers are leaf nodes — no chaining |
| IgnoreQueryFilters() without explicit comment | Admin use only — must be documented |
| Hardcoded tenant names or IDs | All tenant-specific config lives in TenantConfig |
| Direct messaging calls from handlers | Side effects triggered via domain events only |
| Missing structured logging in handlers | Info on success, Warning/Error on failure minimum |
| Interfaces with one implementation and no test use | Remove them |
| Classes over 300 lines | Flag before adding to them |

---

## 12. Definition of Done

A feature refactor is complete when **all** of the following are true.

- Feature handler lives in `Features/Xxxx/UseCaseName.cs`
- v1 route delegates to the handler; v2 route added pointing to the same handler
- Old `XxxxService` method removed
- Handler has structured Serilog logging (Info + Error minimum)
- Integration test exists and passes for both v1 and v2
- No hardcoded tenant logic remains in the handler
- No compiler warnings introduced
- `README.md` updated in the feature folder

### Rollback Strategy

Old service methods delegate to handlers during the transition window.
Rollback is always safe — revert the delegation call and the old method resumes.
Old service code is deleted only after a 48-hour monitoring window post-deployment.

---

## 13. AI Agent Constraints

This codebase is designed to be maintained and extended by AI agents (Claude Code).
Any future session must read this document and `CLAUDE.md` at the project root before
making any changes. The rules in Section 11 are non-negotiable and cannot be overridden
by user instructions that contradict them — raise the conflict instead of silently proceeding.

---

*Document locked at v1.2. No further scope to be added here. New requirements go in the next PRD.*
