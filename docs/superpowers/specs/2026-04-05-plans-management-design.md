# Plans Management — Design Spec

## Problem

Pricing plans are hardcoded in 6 places: 4 frontend files (`AppConfig.ts`, `PricingInformation.tsx`, `BillingDashboard.tsx`, `onboarding/page.tsx`) and 2 backend files (`BillingController.GetPriceId()`, `TenantProvisioningService` plan limits switch). Changing a price or limit requires code changes in all 6 files plus a deploy. The super-admin has no way to manage plans from the UI.

## Solution

Move plan data to a `plans` table in the control DB. Add a super-admin "Plans" page with an editable table. All frontend and backend consumers read from the database via a `GET /api/v2/plans` endpoint. When a price is changed, the backend auto-creates a new Stripe price and archives the old one.

---

## Database Schema

New `plans` table in `redtaxi_control`:

```sql
CREATE TABLE plans (
    id              TEXT PRIMARY KEY,           -- 'solo', 'team', 'fleet', 'enterprise'
    name            TEXT NOT NULL,              -- 'Solo', 'Team', 'Fleet', 'Enterprise'
    description     TEXT NOT NULL DEFAULT '',   -- 'For small operators getting started'
    monthly_price   INTEGER NOT NULL DEFAULT 0, -- Price in pence (19900 = £199)
    annual_price    INTEGER NOT NULL DEFAULT 0, -- Price in pence (15900 = £159)
    stripe_product_id       TEXT,               -- Stripe product ID
    stripe_monthly_price_id TEXT,               -- Stripe monthly price ID
    stripe_annual_price_id  TEXT,               -- Stripe annual price ID
    max_drivers             INTEGER NOT NULL DEFAULT 5,
    max_bookings_per_month  INTEGER NOT NULL DEFAULT 1500,
    features        TEXT[] NOT NULL DEFAULT '{}', -- Feature list as Postgres array
    highlighted     BOOLEAN NOT NULL DEFAULT false,
    sort_order      INTEGER NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    trial_days      INTEGER NOT NULL DEFAULT 7,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Seed Data

```sql
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
     false, 4, 7);
```

---

## Backend

### New Controller: `PlansController`

**File:** `src/backend/RedTaxi.Platform/Controllers/PlansController.cs`

#### `GET /api/v2/plans` (public, no auth)

Returns all active plans ordered by `sort_order`.

Response:
```json
{
  "success": true,
  "data": [
    {
      "id": "solo",
      "name": "Solo",
      "description": "For small operators getting started",
      "monthlyPrice": 19900,
      "annualPrice": 15900,
      "maxDrivers": 5,
      "maxBookingsPerMonth": 1500,
      "features": ["Dispatch console", "Driver mobile app", ...],
      "highlighted": false,
      "trialDays": 7
    }
  ]
}
```

Note: Stripe IDs are NOT returned in the public endpoint.

#### `GET /api/v2/super-admin/plans` (super-admin only)

Returns all plans (including inactive) with Stripe IDs.

#### `PUT /api/v2/super-admin/plans/{planId}` (super-admin only)

Updates plan fields. If `monthlyPrice` or `annualPrice` changes:
1. Create new Stripe Price on the existing Product
2. Update DB with new price ID in a single statement
3. Only archive old Stripe Price AFTER DB commit succeeds
4. If DB write fails after Stripe Price creation, log the orphaned Stripe price ID for manual cleanup

Existing subscribers remain on their current Stripe Price (grandfathered). New checkouts use the new price. This is intentional — price changes do not auto-migrate existing subscriptions.

Request body — all fields optional (partial update):
```json
{
  "name": "Solo Plus",
  "description": "For small operators getting started",
  "monthlyPrice": 22900,
  "annualPrice": 18300,
  "maxDrivers": 8,
  "maxBookingsPerMonth": 2000,
  "features": ["Dispatch console", "Driver app", "Basic reports", "Email support"],
  "highlighted": false,
  "sortOrder": 1,
  "trialDays": 7,
  "isActive": true
}
```

Plans are a fixed set (solo/team/fleet/enterprise). No POST endpoint for creating new plans. To add a plan, insert directly in the DB and set up the Stripe Product manually. Deactivating a plan (`isActive: false`) hides it from the public pricing page and onboarding wizard. Tenants already on a deactivated plan keep their subscription but cannot re-select that plan.

### Refactors

**`BillingController.GetPriceId()`** — replace hardcoded switch with DB lookup:
```csharp
var plan = await conn.QueryFirstOrDefaultAsync<dynamic>(
    "SELECT stripe_monthly_price_id, stripe_annual_price_id FROM plans WHERE id = @Id",
    new { Id = planId });
return interval == "annual" ? plan?.stripe_annual_price_id : plan?.stripe_monthly_price_id;
```

**`BillingController.CreateCheckoutSession()`** — read `trial_days` from DB instead of hardcoded `7`:
```csharp
TrialPeriodDays = plan?.trial_days ?? 7,
```

**`TenantProvisioningService`** — replace plan limits switch with DB lookup:
```csharp
var plan = await conn.QueryFirstOrDefaultAsync<dynamic>(
    "SELECT max_drivers, max_bookings_per_month, trial_days FROM plans WHERE id = @Id",
    new { Id = request.PlanId });
var maxDrivers = plan?.max_drivers ?? 5;
var maxBookings = plan?.max_bookings_per_month ?? 1500;
```

---

## Frontend

### New Page: `/dashboard/admin/plans`

Editable table. Each row is a plan. Each row has its own Save button.

| Column | Input Type | Notes |
|--------|-----------|-------|
| Plan ID | Read-only | `solo`, `team`, etc. |
| Name | Text input | |
| Monthly (£) | Number input | Display as £, store as pence |
| Annual (£) | Number input | Display as £, store as pence |
| Max Drivers | Number input | |
| Max Bookings/mo | Number input | |
| Trial Days | Number input | |
| Features | Edit button → dialog | Textarea with one feature per line |
| Active | Checkbox | |
| Actions | Save button | Per-row save, shows spinner + success/error toast |

"Stripe auto-sync" note below the table: when a price changes, a new Stripe price is created automatically.

### Navigation

Add "Plans" link to Platform Admin nav. Two approaches:
- Add as a second page under the existing "Platform Admin" nav item
- Or add a small sub-nav at the top of `/dashboard/admin` pages

### Refactor: Remove Hardcoded Plans

All 4 frontend files that define plan arrays will be refactored to fetch from `GET /api/v2/plans`:

1. **`PricingInformation.tsx`** — fetch plans from API, render dynamically
2. **`BillingDashboard.tsx`** — fetch plans from API
3. **`onboarding/page.tsx`** — fetch plans from API
4. **`AppConfig.ts`** — remove `PricingPlanList` and `PLAN_ID` constants (or keep as fallback only)

New shared hook or utility: `usePlans()` or `fetchPlans()` in `api.ts`.

---

## File Inventory

| File | Action |
|------|--------|
| `src/backend/RedTaxi.Platform/Controllers/PlansController.cs` | New |
| `src/backend/RedTaxi.Platform/Controllers/BillingController.cs` | Edit — DB lookup |
| `src/backend/RedTaxi.Platform/Services/TenantProvisioningService.cs` | Edit — DB lookup |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/plans/page.tsx` | New |
| `src/frontend/apps/saas-admin/src/lib/api.ts` | Edit — add fetchPlans, updatePlan |
| `src/frontend/apps/saas-admin/src/features/billing/PricingInformation.tsx` | Edit — fetch from API |
| `src/frontend/apps/saas-admin/src/features/billing/BillingDashboard.tsx` | Edit — fetch from API |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/onboarding/page.tsx` | Edit — fetch from API |
| `src/frontend/apps/saas-admin/src/features/dashboard/DashboardHeader.tsx` | Edit — add Plans nav |

---

## Implementation Notes

- **Seed data uses Stripe test-mode IDs.** Production Stripe IDs must be set via the super-admin UI before go-live.
- **Enterprise plan:** price=0, no Stripe prices. Frontend displays "Contact Us" instead of a price or checkout button. BillingDashboard excludes Enterprise from the "Change Plan" cards (as today).
- **Caching:** `GET /api/v2/plans` should use a simple in-memory cache (5-minute TTL), invalidated on PUT. Plans change very rarely.
- **Admin table:** includes `description` and `sort_order` as editable columns. Features column uses a dialog with textarea (one feature per line).

---

## Verification

1. Backend build passes
2. Frontend build passes
3. `GET /api/v2/plans` returns 4 seeded plans (public, no auth)
4. Super-admin `/dashboard/admin/plans` shows editable table with all 4 plans
5. Edit Solo price from £199 → £229 → Save → verify Stripe has new price, DB updated
6. Landing page pricing section shows updated price dynamically
7. Onboarding wizard shows updated plans from API
8. New tenant provision uses DB limits (not hardcoded)
9. Checkout uses DB Stripe price IDs (not hardcoded)
