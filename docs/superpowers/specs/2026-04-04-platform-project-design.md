# RedTaxi.Platform — Separation of SaaS Logic

**Date:** 2026-04-04
**Status:** Approved
**Author:** Peter Farrell / Claude

---

## Problem

SaaS platform logic (tenant provisioning, billing, trial lifecycle, usage metering,
SaaS emails) is scattered across 5 backend projects: API, Application, Data,
Notifications, and Infrastructure. This creates:

- **Unclear ownership** — developers can't tell what's "platform" vs "product"
- **Coupling risk** — changes to platform logic (billing, trials) risk breaking
  tenant operations (bookings, drivers, invoices)
- **Deployment inflexibility** — platform background services (trial lifecycle,
  usage metering) are locked into the API process

## Solution

Create `RedTaxi.Platform` — a new .NET project that owns all SaaS platform
concerns. Zero knowledge of tenant business logic (bookings, drivers, invoices).

## What Platform Owns

### Database
- `ControlDbContext` — the `redtaxi_control` database
- Control DB models: Organization, TenantConfig, TenantUsers
- Control DB migrations (moved from RedTaxi.Data)

### Services
- `ITenantResolver` / `TenantResolver` — given org ID, return connection string
  (called by TenantResolutionMiddleware in API)
- `TenantProvisioningService` — create tenant DB, run migrations, seed data,
  register in control DB
- `TrialLifecycleService` — hourly background job managing trial → grace →
  soft lock → hard lock transitions
- `UsageMeteringService` — check booking/driver counts against plan limits
- `MonthlyCounterResetService` — reset monthly usage counters on 1st of month
- `StripeBillingService` — Stripe checkout, billing portal, subscription status

### Controllers (moved from API)
- `TenantOnboardingController` — POST /api/v2/tenants/provision, GET /tenants
- `TenantStatusController` — GET /api/v2/tenant-status
- `BillingController` — POST /api/v2/billing/create-checkout, /create-portal, /subscription
- `StripeWebhookController` — POST /api/v2/stripe/webhook

### Email
- `ISaasEmailService` / `SaasEmailService` — 13 SaaS email templates via AWS SES
- `SaasEmailTemplates` — welcome, trial reminders, lock notices, payment failed

## What Stays Where It Is

| Project | Keeps | Reason |
|---------|-------|--------|
| RedTaxi.API | TenantResolutionMiddleware, 19 tenant v2 controllers | HTTP pipeline + product logic |
| RedTaxi.Application | 232 MediatR handlers, TenantConfigService | Product logic |
| RedTaxi.Data | RedTaxiDbContext, tenant DB migrations | Per-tenant schema |
| RedTaxi.Notifications | Pusher alerts, operational SMS | Product notifications |
| RedTaxi.Infrastructure | Clerk, Google Maps, Twilio, Revolut | Product integrations |

## Dependency Graph

```
RedTaxi.API ──→ RedTaxi.Platform ──→ RedTaxi.Shared
            ├──→ RedTaxi.Application ──→ RedTaxi.Domain
            │                         ──→ RedTaxi.Data
            ├──→ RedTaxi.Notifications
            └──→ RedTaxi.Infrastructure
```

Platform depends only on RedTaxi.Shared. Zero references to Application, Domain,
Data, Notifications, or Infrastructure.

## Project Structure

```
src/backend/RedTaxi.Platform/
├── RedTaxi.Platform.csproj
├── DependencyInjection.cs          ← AddPlatformServices() extension
├── Data/
│   ├── ControlDbContext.cs
│   ├── Models/
│   │   ├── Organization.cs
│   │   ├── TenantConfig.cs
│   │   └── TenantUsers.cs
│   └── Migrations/
├── Services/
│   ├── ITenantResolver.cs
│   ├── TenantResolver.cs
│   ├── TenantProvisioningService.cs
│   ├── StripeBillingService.cs
│   ├── UsageMeteringService.cs
│   ├── TrialLifecycleService.cs
│   └── MonthlyCounterResetService.cs
├── Email/
│   ├── ISaasEmailService.cs
│   ├── SaasEmailService.cs
│   └── SaasEmailTemplates.cs
└── Controllers/
    ├── TenantOnboardingController.cs
    ├── TenantStatusController.cs
    ├── BillingController.cs
    └── StripeWebhookController.cs
```

## Changes to Existing Projects

### RedTaxi.API
- Remove: 4 controllers (TenantOnboarding, TenantStatus, Billing, StripeWebhook)
- Remove: 3 background services from Program.cs registration
- Remove: UsageMeteringService.cs from Services/
- Simplify: TenantResolutionMiddleware → calls ITenantResolver from Platform
- Add: ProjectReference to RedTaxi.Platform
- Update: Program.cs → call builder.Services.AddPlatformServices(config)

### RedTaxi.Data
- Remove: ControlDbContext + DesignTimeControlDbContextFactory
- Remove: Control DB models (Organization, TenantConfig, TenantUsers)
- Remove: Control DB migrations
- Keep: RedTaxiDbContext, tenant migrations, all tenant entities — unchanged

### RedTaxi.Notifications
- Remove: SaasEmails/ directory (ISaasEmailService, DirectSesSaasEmailService,
  NovuSaasEmailService, SaasEmailTemplates)
- Keep: Operational notification orchestrator, audit log — unchanged

### RedTaxi.Application
- Update: TenantConfigService → use ITenantResolver or ControlDbContext from Platform
  (currently queries ControlDb directly — needs Platform reference or interface)

Note: TenantConfigService in Application currently depends on ControlDbContext.
Two options:
  a) Application references Platform (adds dependency)
  b) Move TenantConfigService to Platform (cleaner — it's platform logic)

Recommendation: Move TenantConfigService to Platform. It reads TenantConfig
from the control DB — that's platform, not product.

## DI Registration

Platform exposes one extension method:

```csharp
public static class DependencyInjection
{
    public static IServiceCollection AddPlatformServices(
        this IServiceCollection services,
        IConfiguration config)
    {
        // ControlDbContext
        services.AddDbContext<ControlDbContext>(o =>
            o.UseNpgsql(config["CONTROL_DB_URL"]));

        // Services
        services.AddScoped<ITenantResolver, TenantResolver>();
        services.AddScoped<ITenantConfigService, TenantConfigService>();
        services.AddScoped<UsageMeteringService>();
        services.AddScoped<StripeBillingService>();
        services.AddScoped<TenantProvisioningService>();
        services.AddTransient<ISaasEmailService, SaasEmailService>();

        // Background services
        services.AddHostedService<TrialLifecycleService>();
        services.AddHostedService<MonthlyCounterResetService>();

        return services;
    }
}
```

## Migration Strategy

This is a **code move, not a rewrite**. Every file moves as-is. No business
logic changes. The steps:

1. Create RedTaxi.Platform.csproj with dependencies (Shared, EF Core, Npgsql, Stripe.net, AWSSDK.SimpleEmail)
2. Move files from source projects to Platform (preserving exact content)
3. Update namespaces from RedTaxi.* to RedTaxi.Platform.*
4. Create DependencyInjection.cs
5. Update API's Program.cs to reference Platform and call AddPlatformServices
6. Update TenantResolutionMiddleware to use ITenantResolver
7. Remove moved files from source projects
8. Verify build + existing tests pass
9. Update docs

## Non-Negotiable Rules (from CLAUDE.md)

- Do NOT change any business logic — this is a move, not a refactor
- Do NOT change any API routes — all endpoints continue at same paths
- Do NOT change response shapes — snapshot tests must pass unchanged
- Controllers remain routing-only — no logic added during move
