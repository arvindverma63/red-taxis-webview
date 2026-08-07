# Plans Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move pricing plans from 6 hardcoded locations to a `plans` table in the control DB, with a super-admin editable table UI and Stripe auto-sync on price changes.

**Architecture:** New `plans` table in `redtaxi_control` (Dapper, not EF). New `PlansController` with public GET + super-admin PUT. Frontend fetches plans from API instead of hardcoded arrays. Price changes auto-create new Stripe prices.

**Tech Stack:** .NET 8, Dapper, PostgreSQL, Stripe.net, Next.js 14, shadcn/ui

**Spec:** `docs/superpowers/specs/2026-04-05-plans-management-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `src/backend/RedTaxi.Platform/Controllers/PlansController.cs` | NEW | GET /api/v2/plans (public) + GET/PUT /api/v2/super-admin/plans (admin) |
| `src/backend/RedTaxi.Platform/Controllers/BillingController.cs` | EDIT | GetPriceId() → DB lookup, CreateCheckoutSession → DB trial_days |
| `src/backend/RedTaxi.Platform/Services/TenantProvisioningService.cs` | EDIT | Plan limits switch → DB lookup |
| `src/frontend/apps/saas-admin/src/lib/api.ts` | EDIT | Add fetchPlans, updatePlan functions + Plan type |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/plans/page.tsx` | NEW | Super-admin plans table page |
| `src/frontend/apps/saas-admin/src/features/billing/PricingInformation.tsx` | EDIT | Fetch plans from API |
| `src/frontend/apps/saas-admin/src/features/billing/BillingDashboard.tsx` | EDIT | Fetch plans from API |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/onboarding/page.tsx` | EDIT | Fetch plans from API |
| `src/frontend/apps/saas-admin/src/features/dashboard/DashboardHeader.tsx` | EDIT | Add Plans nav link |

---

### Task 1: Create plans table + seed data

**Files:**
- Create: SQL script executed against `redtaxi_control`

- [ ] **Step 1: Create plans table and seed 4 plans**

Execute against local `redtaxi_control` database:

```sql
CREATE TABLE IF NOT EXISTS plans (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    description     TEXT NOT NULL DEFAULT '',
    monthly_price   INTEGER NOT NULL DEFAULT 0,
    annual_price    INTEGER NOT NULL DEFAULT 0,
    stripe_product_id       TEXT,
    stripe_monthly_price_id TEXT,
    stripe_annual_price_id  TEXT,
    max_drivers             INTEGER NOT NULL DEFAULT 5,
    max_bookings_per_month  INTEGER NOT NULL DEFAULT 1500,
    features        TEXT[] NOT NULL DEFAULT '{}',
    highlighted     BOOLEAN NOT NULL DEFAULT false,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    trial_days      INTEGER NOT NULL DEFAULT 7,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO plans (id, name, description, monthly_price, annual_price,
    stripe_product_id, stripe_monthly_price_id, stripe_annual_price_id,
    max_drivers, max_bookings_per_month, features, highlighted, sort_order, trial_days)
VALUES
    ('solo', 'Solo', 'For small operators getting started', 19900, 15900,
     'prod_UETUhyh2Uq9h6n', 'price_1TG0YA9D0J4wzb0ZSAjfIJ8G', 'price_1TG0YA9D0J4wzb0Zo0nGVVKk',
     5, 1500, ARRAY['Dispatch console','Driver mobile app','Basic reports','Email support'],
     false, 1, 7),
    ('team', 'Team', 'For growing taxi companies', 38900, 31100,
     'prod_UETVT1Kk6Hfh4G', 'price_1TG0YO9D0J4wzb0Zi6zQ2nyz', 'price_1TG0YO9D0J4wzb0ZilaWad9A',
     20, 5000, ARRAY['Dispatch + Admin','Driver mobile app','Advanced reports','WhatsApp notifications','Priority support'],
     true, 2, 7),
    ('fleet', 'Fleet', 'For established fleets', 79900, 63900,
     'prod_UETV1aE7maY4Kf', 'price_1TG0YP9D0J4wzb0ZYXBxDEF0', 'price_1TG0YP9D0J4wzb0ZwdLLhern',
     50, 15000, ARRAY['All apps included','Full reporting suite','Payment links','WhatsApp + SMS','Dedicated support'],
     false, 3, 7),
    ('enterprise', 'Enterprise', 'For large operators and networks', 0, 0,
     'prod_UETVUvp1Xm5Vnu', NULL, NULL,
     999, 999999, ARRAY['All apps included','Custom integrations','API access','Custom domain','Dedicated support','SLA guarantee'],
     false, 4, 7)
ON CONFLICT (id) DO NOTHING;
```

- [ ] **Step 2: Verify seed data**

Run: `psql -h localhost -U postgres -d redtaxi_control -c "SELECT id, name, monthly_price, max_drivers FROM plans ORDER BY sort_order;"`

Expected:
```
 id         | name       | monthly_price | max_drivers
------------+------------+---------------+-------------
 solo       | Solo       |         19900 |           5
 team       | Team       |         38900 |          20
 fleet      | Fleet      |         79900 |          50
 enterprise | Enterprise |             0 |         999
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: create plans table in control DB with seed data"
```

---

### Task 2: Backend — PlansController

**Files:**
- Create: `src/backend/RedTaxi.Platform/Controllers/PlansController.cs`

- [ ] **Step 1: Create PlansController with 3 endpoints**

```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Caching.Memory;
using Npgsql;
using Dapper;
using Serilog;
using Stripe;
using RedTaxi.Platform.Auth;

namespace RedTaxi.Platform.Controllers;

[ApiController]
[ApiExplorerSettings(GroupName = "v2")]
public class PlansController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly IMemoryCache _cache;
    private static readonly Serilog.ILogger _log = Log.ForContext<PlansController>();
    private const string PlansCacheKey = "plans_all";

    public PlansController(IConfiguration config, IMemoryCache cache)
    {
        _config = config;
        _cache = cache;
    }

    private string ControlDb => _config.GetConnectionString("ControlDb")
        ?? "Host=localhost;Port=5432;Database=redtaxi_control;Username=postgres;Password=postgres";

    /// <summary>
    /// Public endpoint — returns active plans for pricing pages. No Stripe IDs exposed.
    /// </summary>
    [HttpGet("api/v2/plans")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPlans()
    {
        if (_cache.TryGetValue(PlansCacheKey, out object? cached))
            return Ok(cached);

        await using var conn = new NpgsqlConnection(ControlDb);
        await conn.OpenAsync();

        var plans = await conn.QueryAsync<dynamic>(@"
            SELECT id, name, description, monthly_price, annual_price,
                   max_drivers, max_bookings_per_month, features,
                   highlighted, trial_days, sort_order
            FROM plans WHERE is_active = true
            ORDER BY sort_order");

        var result = new { success = true, data = plans };
        _cache.Set(PlansCacheKey, result, TimeSpan.FromMinutes(5));
        return Ok(result);
    }

    /// <summary>
    /// Super-admin — returns ALL plans including inactive, with Stripe IDs.
    /// </summary>
    [HttpGet("api/v2/super-admin/plans")]
    [Authorize]
    public async Task<IActionResult> GetAllPlans()
    {
        if (!SuperAdminAuth.IsSuperAdmin(HttpContext, _config))
            return Forbid();

        await using var conn = new NpgsqlConnection(ControlDb);
        await conn.OpenAsync();

        var plans = await conn.QueryAsync<dynamic>(
            "SELECT * FROM plans ORDER BY sort_order");

        return Ok(new { success = true, data = plans });
    }

    public record UpdatePlanRequest(
        string? Name, string? Description,
        int? MonthlyPrice, int? AnnualPrice,
        int? MaxDrivers, int? MaxBookingsPerMonth,
        string[]? Features, bool? Highlighted,
        int? SortOrder, int? TrialDays, bool? IsActive);

    /// <summary>
    /// Super-admin — update plan. Auto-syncs Stripe prices if price changes.
    /// </summary>
    [HttpPut("api/v2/super-admin/plans/{planId}")]
    [Authorize]
    public async Task<IActionResult> UpdatePlan(string planId, [FromBody] UpdatePlanRequest request)
    {
        if (!SuperAdminAuth.IsSuperAdmin(HttpContext, _config))
            return Forbid();

        await using var conn = new NpgsqlConnection(ControlDb);
        await conn.OpenAsync();

        // Read current plan
        var current = await conn.QueryFirstOrDefaultAsync<dynamic>(
            "SELECT * FROM plans WHERE id = @Id", new { Id = planId });
        if (current == null)
            return NotFound(new { error = "Plan not found" });

        // Check if prices changed — need Stripe sync
        string? newMonthlyPriceId = null;
        string? newAnnualPriceId = null;

        var stripeKey = _config["Stripe:SecretKey"]
            ?? Environment.GetEnvironmentVariable("STRIPE_SECRET_KEY");

        if (!string.IsNullOrEmpty(stripeKey) && !string.IsNullOrEmpty((string?)current.stripe_product_id))
        {
            StripeConfiguration.ApiKey = stripeKey;
            var priceService = new PriceService();

            // Monthly price changed?
            if (request.MonthlyPrice.HasValue && request.MonthlyPrice.Value != (int)current.monthly_price
                && request.MonthlyPrice.Value > 0)
            {
                var newPrice = await priceService.CreateAsync(new PriceCreateOptions
                {
                    Product = (string)current.stripe_product_id,
                    UnitAmount = request.MonthlyPrice.Value,
                    Currency = "gbp",
                    Recurring = new PriceRecurringOptions { Interval = "month" },
                });
                newMonthlyPriceId = newPrice.Id;
                _log.Information("Created Stripe monthly price {PriceId} for plan {PlanId}", newPrice.Id, planId);
            }

            // Annual price changed?
            if (request.AnnualPrice.HasValue && request.AnnualPrice.Value != (int)current.annual_price
                && request.AnnualPrice.Value > 0)
            {
                var newPrice = await priceService.CreateAsync(new PriceCreateOptions
                {
                    Product = (string)current.stripe_product_id,
                    UnitAmount = request.AnnualPrice.Value,
                    Currency = "gbp",
                    Recurring = new PriceRecurringOptions { Interval = "year" },
                });
                newAnnualPriceId = newPrice.Id;
                _log.Information("Created Stripe annual price {PriceId} for plan {PlanId}", newPrice.Id, planId);
            }
        }

        // Build dynamic UPDATE
        var updates = new List<string>();
        var args = new DynamicParameters();
        args.Add("Id", planId);

        if (request.Name != null) { updates.Add("name = @Name"); args.Add("Name", request.Name); }
        if (request.Description != null) { updates.Add("description = @Desc"); args.Add("Desc", request.Description); }
        if (request.MonthlyPrice.HasValue) { updates.Add("monthly_price = @MonthlyPrice"); args.Add("MonthlyPrice", request.MonthlyPrice.Value); }
        if (request.AnnualPrice.HasValue) { updates.Add("annual_price = @AnnualPrice"); args.Add("AnnualPrice", request.AnnualPrice.Value); }
        if (newMonthlyPriceId != null) { updates.Add("stripe_monthly_price_id = @StripeMPId"); args.Add("StripeMPId", newMonthlyPriceId); }
        if (newAnnualPriceId != null) { updates.Add("stripe_annual_price_id = @StripeAPId"); args.Add("StripeAPId", newAnnualPriceId); }
        if (request.MaxDrivers.HasValue) { updates.Add("max_drivers = @MaxDrivers"); args.Add("MaxDrivers", request.MaxDrivers.Value); }
        if (request.MaxBookingsPerMonth.HasValue) { updates.Add("max_bookings_per_month = @MaxBookings"); args.Add("MaxBookings", request.MaxBookingsPerMonth.Value); }
        if (request.Features != null) { updates.Add("features = @Features"); args.Add("Features", request.Features); }
        if (request.Highlighted.HasValue) { updates.Add("highlighted = @Highlighted"); args.Add("Highlighted", request.Highlighted.Value); }
        if (request.SortOrder.HasValue) { updates.Add("sort_order = @SortOrder"); args.Add("SortOrder", request.SortOrder.Value); }
        if (request.TrialDays.HasValue) { updates.Add("trial_days = @TrialDays"); args.Add("TrialDays", request.TrialDays.Value); }
        if (request.IsActive.HasValue) { updates.Add("is_active = @IsActive"); args.Add("IsActive", request.IsActive.Value); }

        if (updates.Count == 0)
            return Ok(new { success = true });

        updates.Add("updated_at = NOW()");
        await conn.ExecuteAsync($"UPDATE plans SET {string.Join(", ", updates)} WHERE id = @Id", args);

        // Archive old Stripe prices AFTER DB commit succeeds
        if (!string.IsNullOrEmpty(stripeKey))
        {
            var priceService = new PriceService();
            if (newMonthlyPriceId != null && !string.IsNullOrEmpty((string?)current.stripe_monthly_price_id))
            {
                try { await priceService.UpdateAsync((string)current.stripe_monthly_price_id, new PriceUpdateOptions { Active = false }); }
                catch (Exception ex) { _log.Warning(ex, "Failed to archive old Stripe price {PriceId}", current.stripe_monthly_price_id); }
            }
            if (newAnnualPriceId != null && !string.IsNullOrEmpty((string?)current.stripe_annual_price_id))
            {
                try { await priceService.UpdateAsync((string)current.stripe_annual_price_id, new PriceUpdateOptions { Active = false }); }
                catch (Exception ex) { _log.Warning(ex, "Failed to archive old Stripe price {PriceId}", current.stripe_annual_price_id); }
            }
        }

        // Invalidate cache
        _cache.Remove(PlansCacheKey);

        _log.Information("Super-admin updated plan {PlanId}: {Fields}",
            planId, string.Join(", ", updates.Where(u => u != "updated_at = NOW()")));

        return Ok(new { success = true });
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Platform/RedTaxi.Platform.csproj --no-restore`
Expected: Build succeeded

- [ ] **Step 3: Commit**

```bash
git add src/backend/RedTaxi.Platform/Controllers/PlansController.cs
git commit -m "feat: PlansController — public GET + super-admin PUT with Stripe sync"
```

---

### Task 3: Backend — Refactor hardcoded lookups

**Files:**
- Modify: `src/backend/RedTaxi.Platform/Controllers/BillingController.cs` (lines 99, 240-253)
- Modify: `src/backend/RedTaxi.Platform/Services/TenantProvisioningService.cs` (lines 179-187)

- [ ] **Step 1: Refactor BillingController.GetPriceId to async DB lookup**

Replace the `GetPriceId` method (lines 240-253) with:
```csharp
private async Task<(string? priceId, int trialDays)> GetPlanPricing(string planId, string interval)
{
    var controlDb = _config.GetConnectionString("ControlDb")
        ?? "Host=localhost;Port=5432;Database=redtaxi_control;Username=postgres;Password=postgres";
    await using var conn = new NpgsqlConnection(controlDb);
    await conn.OpenAsync();
    var plan = await conn.QueryFirstOrDefaultAsync<dynamic>(
        "SELECT stripe_monthly_price_id, stripe_annual_price_id, trial_days FROM plans WHERE id = @Id AND is_active = true",
        new { Id = planId });
    if (plan == null) return (null, 7);
    var priceId = interval == "annual"
        ? (string?)plan.stripe_annual_price_id
        : (string?)plan.stripe_monthly_price_id;
    return (priceId, (int?)plan.trial_days ?? 7);
}
```

Update `CreateCheckoutSession` to call the new method:
- Replace `var priceId = GetPriceId(request.PlanId, request.BillingInterval);` with `var (priceId, trialDays) = await GetPlanPricing(request.PlanId, request.BillingInterval);`
- Replace `TrialPeriodDays = 7,` with `TrialPeriodDays = trialDays,`

- [ ] **Step 2: Refactor TenantProvisioningService plan limits**

Replace the switch statement (lines 179-187) with:
```csharp
// 6. Plan limits from DB
int maxDrivers = 5, maxBookings = 1500;
try
{
    await using var planConn = new NpgsqlConnection(controlDb);
    await planConn.OpenAsync();
    var planLimits = await planConn.QueryFirstOrDefaultAsync<dynamic>(
        "SELECT max_drivers, max_bookings_per_month FROM plans WHERE id = @Id",
        new { Id = request.PlanId });
    if (planLimits != null)
    {
        maxDrivers = (int?)planLimits.max_drivers ?? 5;
        maxBookings = (int?)planLimits.max_bookings_per_month ?? 1500;
    }
}
catch { /* Fallback to defaults */ }
```

- [ ] **Step 3: Build and verify**

Run: `cd src/backend && dotnet build RedTaxi.Platform/RedTaxi.Platform.csproj --no-restore`
Expected: Build succeeded

- [ ] **Step 4: Commit**

```bash
git add src/backend/RedTaxi.Platform/Controllers/BillingController.cs src/backend/RedTaxi.Platform/Services/TenantProvisioningService.cs
git commit -m "refactor: BillingController + ProvisioningService read plan data from DB"
```

---

### Task 4: Frontend — API client + Plan type

**Files:**
- Modify: `src/frontend/apps/saas-admin/src/lib/api.ts`

- [ ] **Step 1: Add Plan type and API functions**

Add to `api.ts`:
```typescript
export type Plan = {
  id: string;
  name: string;
  description: string;
  monthly_price: number;  // pence
  annual_price: number;   // pence
  max_drivers: number;
  max_bookings_per_month: number;
  features: string[];
  highlighted: boolean;
  trial_days: number;
  sort_order: number;
  // Admin-only fields (from super-admin endpoint):
  stripe_product_id?: string;
  stripe_monthly_price_id?: string;
  stripe_annual_price_id?: string;
  is_active?: boolean;
};

export async function fetchPlans(): Promise<Plan[]> {
  // Public endpoint — no auth needed
  const res = await fetch(`${API_BASE}/api/v2/plans`);
  if (!res.ok) throw new Error(`API error ${res.status}`);
  const json = await res.json();
  return json.data;
}

export async function fetchAdminPlans(token: string): Promise<Plan[]> {
  return apiFetch<Plan[]>('/api/v2/super-admin/plans', token);
}

export async function updatePlan(
  token: string,
  planId: string,
  data: Partial<Omit<Plan, 'id' | 'stripe_product_id' | 'stripe_monthly_price_id' | 'stripe_annual_price_id'>>,
): Promise<void> {
  const resolved = await resolveToken(token);
  const res = await fetch(`${API_BASE}/api/v2/super-admin/plans/${planId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${resolved}` },
    body: JSON.stringify(data),
  });
  if (!res.ok) throw new Error(`API error ${res.status}`);
}
```

- [ ] **Step 2: Commit**

```bash
git add src/frontend/apps/saas-admin/src/lib/api.ts
git commit -m "feat: add Plan type + fetchPlans/updatePlan API functions"
```

---

### Task 5: Frontend — Plans admin page

**Files:**
- Create: `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/plans/page.tsx`
- Modify: `src/frontend/apps/saas-admin/src/features/dashboard/DashboardHeader.tsx`

- [ ] **Step 1: Create plans admin page** — editable table with per-row Save

- [ ] **Step 2: Add "Plans" to Platform Admin nav** in DashboardHeader.tsx — extend the `menu` array:
```typescript
if (isSuperAdmin) {
  return [
    ...props.menu,
    { href: '/dashboard/admin', label: 'Tenants' },
    { href: '/dashboard/admin/plans', label: 'Plans' },
  ];
}
```

- [ ] **Step 3: Build and verify**

Run: `cd src/frontend/apps/saas-admin && npx next build`
Expected: Build succeeded, `/en/dashboard/admin/plans` in route list

- [ ] **Step 4: Commit**

```bash
git add "src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/plans/page.tsx" src/frontend/apps/saas-admin/src/features/dashboard/DashboardHeader.tsx
git commit -m "feat: super-admin plans management page with editable table"
```

---

### Task 6: Frontend — Refactor hardcoded plan arrays to API fetch

**Files:**
- Modify: `src/frontend/apps/saas-admin/src/features/billing/PricingInformation.tsx`
- Modify: `src/frontend/apps/saas-admin/src/features/billing/BillingDashboard.tsx`
- Modify: `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/onboarding/page.tsx`

- [ ] **Step 1: Refactor PricingInformation.tsx** — replace hardcoded `plans` array (lines 23-94) with `fetchPlans()` call. Use `useEffect` + `useState`. Format `monthly_price / 100` for display. Enterprise plan shows "Contact Us".

- [ ] **Step 2: Refactor BillingDashboard.tsx** — replace hardcoded `plans` array (lines 28-56) with `fetchPlans()` call. Filter out enterprise for "Change Plan" cards.

- [ ] **Step 3: Refactor onboarding/page.tsx** — replace hardcoded `plans` array (lines 43-75) with `fetchPlans()` call. Filter to non-enterprise active plans.

- [ ] **Step 4: Build and verify**

Run: `cd src/frontend/apps/saas-admin && npx next build`
Expected: Build succeeded

- [ ] **Step 5: Commit**

```bash
git add src/frontend/apps/saas-admin/src/features/billing/PricingInformation.tsx src/frontend/apps/saas-admin/src/features/billing/BillingDashboard.tsx "src/frontend/apps/saas-admin/src/app/[locale]/(auth)/onboarding/page.tsx"
git commit -m "refactor: all plan arrays now fetch from GET /api/v2/plans"
```

---

### Task 7: Verify end-to-end

- [ ] **Step 1: Restart API** with new code
- [ ] **Step 2: Test** `GET /api/v2/plans` returns 4 plans (public, no auth)
- [ ] **Step 3: Test** `GET /api/v2/super-admin/plans` returns all plans with Stripe IDs
- [ ] **Step 4: Test** `PUT /api/v2/super-admin/plans/solo` updates name → verify in DB
- [ ] **Step 5: Test** landing page pricing shows plans from API
- [ ] **Step 6: Test** super-admin `/dashboard/admin/plans` shows editable table
- [ ] **Step 7: Test** edit Solo price → Save → verify Stripe price created
- [ ] **Step 8: Commit** docs update
