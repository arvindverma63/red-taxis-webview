# Super-Admin Platform Management — Design Spec

## Context

Red Taxi is a multi-tenant SaaS taxi dispatch platform. The saas-admin app (`src/frontend/apps/saas-admin/`) at redtaxi.co.uk handles tenant self-service: onboarding, dashboard, billing, settings. There is currently no way for the platform owner to view registered tenants, check their usage, override limits, or change account status. This spec adds a super-admin section to the saas-admin app.

## Requirements

- Platform owner needs to see all registered tenants and their status
- Override usage counts (bookings_used, sms_balance)
- Change plan and limits (max_drivers, max_bookings_per_month)
- Manually control tenant status (active, trial, locked) and extend trials
- Read-only view of tenant config entries
- Super-admin access controlled by Clerk org ID matching `SUPER_ADMIN_ORG_ID` env var
- Test login: `peter.farrell1@gmail.com` / `Polopolopolo121` in Clerk with a "Red Taxi Platform" org

## Architecture

### Auth

- Create Clerk user `peter.farrell1@gmail.com` with a "Red Taxi Platform" org
- Set `SUPER_ADMIN_ORG_ID` env var (backend) and `NEXT_PUBLIC_SUPER_ADMIN_ORG_ID` (frontend) to the new org's ID
- Backend: extract `IsSuperAdmin()` from `TenantOnboardingController` into a shared static helper `SuperAdminAuth.IsSuperAdmin(HttpContext, IConfiguration)` so both existing and new controllers can use it
- Frontend: conditional nav item rendered inside `DashboardHeader.tsx` (which is already a client component using `useAuth()`) — NOT in `layout.tsx` (which is a server component)
- Admin pages redirect non-super-admin users to `/dashboard`
- Note: `NEXT_PUBLIC_SUPER_ADMIN_ORG_ID` exposes the org ID in the client bundle. This is acceptable for the current scale — the backend still validates on every request. A server-side role claim approach is more secure long-term.

### Frontend Routes (in saas-admin)

| Route | Page | Purpose |
|-------|------|---------|
| `/dashboard/admin` | Tenant list | Table of all tenants with status, plan, usage, quick actions |
| `/dashboard/admin/[orgId]` | Tenant detail | 4 editable cards + read-only config table |

### Navigation

Conditional "Platform Admin" nav item added inside `DashboardHeader.tsx` using `useAuth().orgId` comparison. Only visible when org matches super-admin org. No sidebar — consistent with the rest of saas-admin.

---

## Page 1: Tenant List (`/dashboard/admin`)

### Table Columns

| Column | Source | Display |
|--------|--------|---------|
| Company | `company_name` | Text + link to detail page |
| Plan | `plan_id` | Badge (grey=solo, blue=team, purple=fleet, amber=enterprise) |
| Status | `status` | Badge (green=active, blue=trial, yellow=grace, red=locked) |
| Bookings | `bookings_used_this_month` / `max_bookings_per_month` | Progress bar with numbers |
| SMS | `sms_balance` | Number |
| Trial Ends | `trial_ends_at` | Relative date ("3 days") or "—" if no trial |
| Actions | — | Dropdown menu |

### Quick Actions (per-row dropdown)

- **View Details** → navigate to `/dashboard/admin/[orgId]`
- **Lock Tenant** → `PUT /api/v2/super-admin/tenants/{orgId}/status` with `status: "soft_locked"` (requires confirmation dialog)
- **Unlock Tenant** → same endpoint with `status: "active"`
- **Extend Trial +7 days** → same endpoint with `trialEndsAt` set to current + 7 days

### Data Source

`GET /api/v2/tenants` — enhanced to include `bookings_used_this_month`, `sms_balance`, `trial_ends_at`, `database_provisioned` in the response. Uses `apiFetch<TenantSummary[]>('/api/v2/tenants', token)`.

---

## Page 2: Tenant Detail (`/dashboard/admin/[orgId]`)

### Header

Back button (← Tenants) + Company name + Plan badge + Status badge

### Data Source

Uses existing `fetchTenantDetails(token, orgId)` from `api.ts` which calls `GET /api/v2/tenants/{orgId}`. The existing endpoint already allows super-admin access to any tenant's data. Note: the existing `SELECT *` returns `database_url` with Postgres credentials — this must be excluded from the response (see Backend Changes).

### Card 1: Company Profile (editable)

| Field | Type | Source |
|-------|------|--------|
| Company Name | text input | `company_name` |
| Phone | tel input | `phone` |
| Email | email input | `email` |
| Postcode | text input | `postcode` |

Save → `PATCH /api/v2/tenants/{orgId}` (existing endpoint, already allows super-admin to edit any tenant)

### Card 2: Plan & Limits (editable)

| Field | Type | Source |
|-------|------|--------|
| Plan | select (Solo/Team/Fleet/Enterprise) | `plan_id` |
| Max Drivers | number input | `max_drivers` |
| Max Bookings/Month | number input | `max_bookings_per_month` |

Save → `PUT /api/v2/super-admin/tenants/{orgId}/limits` (new)

### Card 3: Usage Overrides (editable)

| Field | Type | Source |
|-------|------|--------|
| Bookings Used This Month | number input | `bookings_used_this_month` |
| SMS Balance | number input | `sms_balance` |

Save → `PUT /api/v2/super-admin/tenants/{orgId}/usage` (new)

### Card 4: Status & Trial (editable)

| Field | Type | Source |
|-------|------|--------|
| Status | select (active, active_trial, grace_period, soft_locked, hard_locked) | `status` |
| Trial Ends At | date input + "Extend +7 days" button | `trial_ends_at` |

Save → `PUT /api/v2/super-admin/tenants/{orgId}/status` (new). Changing to `soft_locked` or `hard_locked` requires a confirmation dialog.

### Config Section (read-only, collapsible)

Table of all `tenant_config` entries for this org. Two columns: Key, Value. Collapsed by default, expandable with a "Show Config" toggle. Data from the `config` array in the `fetchTenantDetails` response.

---

## UX Behavior

- **Save buttons:** Disabled during save, show spinner. Re-enable on completion.
- **Success:** Toast notification "Saved" on successful mutation.
- **Errors:** Toast notification with error message on failure.
- **Confirmation dialogs:** Required for Lock Tenant, Hard Lock, and status changes to `soft_locked` or `hard_locked`. Use the existing `AlertDialog` or simple `window.confirm`.
- **After mutation:** Refetch tenant data (no optimistic updates — data is critical).
- **Loading:** Skeleton/shimmer cards while tenant data loads.

---

## Backend Changes

### Pre-requisite: Extract `IsSuperAdmin()` helper

Extract from `TenantOnboardingController` into a shared static helper:

**File:** `src/backend/RedTaxi.Platform/Auth/SuperAdminAuth.cs`
```csharp
public static class SuperAdminAuth
{
    public static bool IsSuperAdmin(HttpContext httpContext, IConfiguration config)
    {
        var superAdminOrgId = config["SaaS:SuperAdminOrgId"]
            ?? Environment.GetEnvironmentVariable("SUPER_ADMIN_ORG_ID")
            ?? "org_ace_taxis";
        var callerOrgId = httpContext.Items["TenantOrgId"] as string;
        return !string.IsNullOrEmpty(callerOrgId) && callerOrgId == superAdminOrgId;
    }
}
```

Update `TenantOnboardingController.IsSuperAdmin()` to delegate to this helper.

### Existing Endpoint Enhancements

**`GET /api/v2/tenants`** — add fields to the SELECT:
```sql
SELECT id, company_name, slug, status, plan_id,
       max_drivers, max_bookings_per_month,
       bookings_used_this_month, sms_balance,
       trial_ends_at, database_provisioned,
       created_at
FROM organization ORDER BY created_at DESC
```

**`GET /api/v2/tenants/{orgId}`** — replace `SELECT *` with explicit column list excluding `database_url` and sensitive Stripe fields:
```sql
SELECT id, company_name, slug, phone, email, postcode,
       plan_id, status, max_drivers, max_bookings_per_month,
       bookings_used_this_month, sms_balance,
       trial_ends_at, locked_at,
       database_provisioned, onboarding_complete,
       created_at, updated_at
FROM organization WHERE id = @OrgId
```

### New Controller: `SuperAdminController`

**File:** `src/backend/RedTaxi.Platform/Controllers/SuperAdminController.cs`
**Route prefix:** `/api/v2/super-admin/tenants`
**All endpoints require `SuperAdminAuth.IsSuperAdmin()` check.**
**All endpoints log the caller's org ID and the change made (structured Serilog logging).**

#### `PUT /{orgId}/limits`

Request: `{ planId?: string, maxDrivers?: int, maxBookingsPerMonth?: int }`
Response: `{ success: true }`

Updates `plan_id`, `max_drivers`, `max_bookings_per_month` on the `organization` table.

#### `PUT /{orgId}/usage`

Request: `{ bookingsUsedThisMonth?: int, smsBalance?: int }`
Response: `{ success: true }`

Updates `bookings_used_this_month`, `sms_balance` on the `organization` table.

#### `PUT /{orgId}/status`

Request: `{ status?: string, trialEndsAt?: DateTime }`
Response: `{ success: true }`

Updates `status`, `trial_ends_at` on the `organization` table. If status is `soft_locked` or `hard_locked`, also sets `locked_at = NOW()`. If unlocking (active/active_trial), clears `locked_at`.

---

## Frontend Types

Add to `src/frontend/apps/saas-admin/src/lib/api.ts`:

```typescript
export type TenantSummary = {
  id: string;
  company_name: string;
  slug: string;
  status: string;
  plan_id: string;
  max_drivers: number;
  max_bookings_per_month: number;
  bookings_used_this_month: number;
  sms_balance: number;
  trial_ends_at: string | null;
  database_provisioned: boolean;
  created_at: string;
};
```

## Frontend API Client Additions

```typescript
export async function fetchAllTenants(token: string): Promise<TenantSummary[]>
// GET /api/v2/tenants — uses apiFetch (unwraps .data)

export async function updateTenantLimits(token: string, orgId: string, data: {
  planId?: string; maxDrivers?: number; maxBookingsPerMonth?: number;
}): Promise<void>
// PUT /api/v2/super-admin/tenants/{orgId}/limits

export async function updateTenantUsage(token: string, orgId: string, data: {
  bookingsUsedThisMonth?: number; smsBalance?: number;
}): Promise<void>
// PUT /api/v2/super-admin/tenants/{orgId}/usage

export async function updateTenantStatus(token: string, orgId: string, data: {
  status?: string; trialEndsAt?: string;
}): Promise<void>
// PUT /api/v2/super-admin/tenants/{orgId}/status
```

---

## File Inventory

| File | Action | Purpose |
|------|--------|---------|
| `src/backend/RedTaxi.Platform/Auth/SuperAdminAuth.cs` | New | Shared IsSuperAdmin() helper |
| `src/backend/RedTaxi.Platform/Controllers/SuperAdminController.cs` | New | 3 PUT endpoints for limits/usage/status |
| `src/backend/RedTaxi.Platform/Controllers/TenantOnboardingController.cs` | Edit | Enrich GET /tenants, fix SELECT * in GetTenant, delegate IsSuperAdmin |
| `src/frontend/apps/saas-admin/src/features/dashboard/DashboardHeader.tsx` | Edit | Add conditional "Platform Admin" nav item |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/page.tsx` | New | Tenant list page |
| `src/frontend/apps/saas-admin/src/app/[locale]/(auth)/dashboard/admin/[orgId]/page.tsx` | New | Tenant detail page |
| `src/frontend/apps/saas-admin/src/lib/api.ts` | Edit | Add TenantSummary type + 4 API functions |

---

## Verification

1. Sign in as `peter.farrell1@gmail.com` (Red Taxi Platform org) → see "Platform Admin" in nav
2. Navigate to `/dashboard/admin` → see tenants (Ace Taxis, Test Taxis, Demo Cabs)
3. Click into a tenant → see 4 cards with current data pre-filled
4. Edit limits → save → toast "Saved" → reload → values persisted
5. Override usage → save → check via `GET /api/v2/tenant-status` for that tenant
6. Change status to `soft_locked` → confirmation dialog → verify banner shows on tenant's dashboard
7. Extend trial → verify `trial_ends_at` updated
8. Sign in as a regular tenant user → verify "Platform Admin" nav item is NOT visible
9. Verify `database_url` is NOT returned by `GET /api/v2/tenants/{orgId}`
10. Backend build: `dotnet build RedTaxi.Platform` passes
11. Frontend build: `cd saas-admin && npm run build` passes
12. Re-record smoke test for `GET /api/v2/tenants` to capture new fields
