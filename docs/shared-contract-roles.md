# Red Taxi — Shared Contract: Roles & User Identity

**Version:** 1.0
**Status:** Draft — must be approved before any v2 PRD implementation begins
**Created:** 2026-03-29
**Referenced by:** PRD v2a, PRD v2b, PRD v2c, PRD v2d

> This document defines the shared contract for user identity and roles across
> all v2 workstreams. All 4 Codex agents must build against this contract.
> No agent may define its own role logic.

---

## 1. Decision: Split Ownership

| Concern | Owner | Where |
|---------|-------|-------|
| **Identity** (who you are) | Clerk | Clerk cloud |
| **Roles** (what you can do) | Tenant DB | `AspNetUserRoles` + `AppRoles` |
| **User record** (FK target) | Tenant DB | `AppUsers` |
| **Driver profile** (business data) | Tenant DB | `AppUserProfiles` |

### Rationale
- Clerk's built-in org roles are too generic (admin/member/guest). We need
  Admin, User, Driver, Account — custom roles require Clerk enterprise or
  abusing `publicMetadata` as a key-value store.
- Role is tenant-scoped business data ("Peter is Admin at Ace Taxis") — it
  belongs alongside bookings and driver profiles, not in an external auth provider.
- The backend already checks roles in handlers, middleware, and controllers
  via DB queries. Moving to Clerk would mean API calls or JWT parsing for
  every role check.
- Clean separation: Clerk answers "is this person authenticated?", the tenant
  DB answers "what can they do here?"

---

## 2. Role Definitions

Defined in `AppRoles` table, seeded during tenant provisioning:

| RoleId | Name | Used by | Description |
|--------|------|---------|-------------|
| 1 | Admin | Admin app, Dispatch | Full access. Billing, audit, settings, driver management. |
| 2 | User | Admin app, Dispatch | Staff/controller. Booking views and dispatch only. No billing, drivers, accounts, settings. |
| 3 | Driver | Dispatch, Driver app | Driver-specific restrictions in dispatch UI. Cannot cancel, cannot edit pricing, limited booking actions. |
| 4 | Account | Account Booker | Account-linked web booker. Can create and view own bookings only. |

These 4 roles are **fixed for v2**. No new roles without a decision record.

---

## 3. Schema

### Tables (existing — no changes needed)

```
AppUsers
├── Id              INT (PK, auto-increment) — FK target for bookings, profiles, etc.
├── ClerkUserId     VARCHAR(64) (NEW, unique index) — maps Clerk sub claim to local user
├── UserName        VARCHAR(256)
├── FullName        VARCHAR(50)
├── Email           VARCHAR(256)
├── PhoneNumber     VARCHAR(20)
└── [Identity columns nulled out: PasswordHash, SecurityStamp, etc.]

AspNetUserRoles
├── UserId          INT (FK → AppUsers.Id)
└── RoleId          INT (FK → AppRoles.Id)

AppRoles
├── Id              INT (PK) — 1=Admin, 2=User, 3=Driver, 4=Account
└── Name            VARCHAR(256)

AppUserProfiles (drivers only)
├── UserId          INT (PK, FK → AppUsers.Id)
├── RegNo, VehicleMake, VehicleModel, VehicleColour, VehicleType
├── Longitude, Latitude, Heading, Speed, GpsLastUpdated
├── NotificationFCM, ChromeFCM
├── CashCommissionRate, CommsPlatform
├── ShowAllBookings, ShowHVSBookings
├── IsDeleted, LastLogin, NonAce
└── ColorCodeRGB
```

### Control DB (existing — no changes)

```
tenant_users
├── org_id          VARCHAR (FK → organization.id)
├── email           VARCHAR
├── username        VARCHAR
├── role            VARCHAR ('Admin', 'User', 'Driver', 'Account')
└── is_owner        BOOLEAN
```

`tenant_users.role` is a **denormalised copy** for login routing only (so
TenantResolutionMiddleware can resolve tenant before the tenant DB is connected).
The source of truth is `AspNetUserRoles` in the tenant DB.

---

## 4. Auth Flow (post-v2a)

```
1. User authenticates with Clerk (frontend)
2. Clerk issues RS256 JWT with:
   - sub: clerk_user_id (e.g. "user_2xAb3...")
   - org_id: clerk_org_id (e.g. "org_ace_taxis")
   - No role claim — Clerk doesn't own roles

3. Frontend sends JWT in Authorization header

4. Backend middleware chain:
   a) Clerk JWT validation (RS256, JWKS)
   b) TenantResolutionMiddleware:
      - Reads org_id → resolves tenant connection string
   c) ClerkUserResolutionMiddleware (NEW):
      - Reads sub claim → looks up AppUsers.ClerkUserId
      - Joins AspNetUserRoles + AppRoles to get role
      - Sets HttpContext.Items["UserId"] = (int)
      - Sets HttpContext.Items["UserRole"] = "Admin" | "User" | "Driver" | "Account"
      - Sets HttpContext.Items["UserRoleId"] = (int) 1-4
      - Caches mapping in-memory (ConcurrentDictionary)

5. Handlers/controllers read from HttpContext.Items — no UserManager needed
```

---

## 5. The `/api/v2/users/me` Endpoint

**Built by:** PRD v2a (auth consolidation)
**Consumed by:** PRD v2b (admin), PRD v2d (dispatch), account booker, driver app

### Request
```
GET /api/v2/users/me
Authorization: Bearer <clerk-jwt>
```

### Response
```json
{
  "success": true,
  "data": {
    "userId": 42,
    "clerkUserId": "user_2xAb3...",
    "username": "peter",
    "fullName": "Peter Smith",
    "email": "peter@acetaxis.co.uk",
    "phone": "07700900123",
    "role": "Admin",
    "roleId": 1,
    "permissions": {
      "canViewBilling": true,
      "canManageDrivers": true,
      "canManageAccounts": true,
      "canViewAudit": true,
      "canCancelBookings": true,
      "canManageSettings": true,
      "canViewFinancialReports": true
    }
  }
}
```

### Permission Mapping

Derived from roleId — not stored separately. Calculated in the handler:

```
Admin (1):
  All permissions = true

User (2):
  canViewBilling = false
  canManageDrivers = false
  canManageAccounts = false
  canViewAudit = false
  canCancelBookings = false (bulk cancel — individual cancel allowed)
  canManageSettings = false
  canViewFinancialReports = false

Driver (3):
  All permissions = false (driver app has its own permission model)

Account (4):
  All permissions = false (account booker has its own permission model)
```

### Why both `roleId` (int) and `role` (string)?
- `roleId` — backwards compatibility. Dispatch has 15+ checks like `roleId !== 3`.
  We're not rebuilding dispatch, so it needs the int.
- `role` — new code in admin rebuild uses readable strings. No magic numbers.
- `permissions` — flattens the `roleId === 1` / `roleId !== 2` conditionals into
  explicit booleans. Frontend route guards become `if (!me.permissions.canViewBilling)`.

---

## 6. How Each Agent Uses This Contract

### PRD v2a (Auth Consolidation) — PRODUCES the contract
- Adds `ClerkUserId` column to `AppUsers`
- Builds `ClerkUserResolutionMiddleware` (maps Clerk sub → UserId + Role)
- Builds `GET /api/v2/users/me` endpoint
- Backfills ClerkUserId for Ace Taxis users
- **Does NOT change AppRoles or AspNetUserRoles — they stay as-is**

### PRD v2b (Admin Frontend Rebuild) — CONSUMES the contract
- Calls `GET /api/v2/users/me` on app load, caches in React context
- Uses `permissions` object for route guards and UI visibility
- Uses `role` string (not `roleId` int) in new code
- Manages role assignment via admin UI → `PUT /api/v2/users/{id}/role`

### PRD v2c (v2 API Completion) — CONSUMES the contract
- Role-gated endpoints read `HttpContext.Items["UserRole"]`
- Example: `[Authorize]` on all endpoints + handler checks `UserRole == "Admin"` for audit/settings
- **Does NOT introduce new roles or permissions**

### PRD v2d (Dispatch Auth Swap) — CONSUMES the contract
- Calls `GET /api/v2/users/me` on app load
- Stores `roleId` (int) for existing dispatch checks (`roleId !== 3`)
- **Does NOT change any dispatch role logic — just changes where roleId comes from**

---

## 7. User Lifecycle

### New driver (post-v2a)
1. Admin creates driver in admin UI
2. Backend: INSERT AppUsers (no password) + AppUserProfiles + AspNetUserRoles (Driver)
3. Backend: Clerk API → invite user to org by email
4. Backend: INSERT tenant_users in control DB (for login routing)
5. Driver receives Clerk invitation → sets own password
6. Driver logs in → Clerk JWT → ClerkUserResolutionMiddleware resolves to local UserId

### New staff/admin user (post-v2a)
1. Admin invites via Clerk `<OrganizationProfile />` component
2. Backend: INSERT AppUsers (no password) + AspNetUserRoles (Admin or User)
3. Backend: INSERT tenant_users in control DB
4. User receives Clerk invitation → sets own password

### New account web booker (post-v2a)
1. Admin registers account web booker in admin UI
2. Backend: INSERT AppUsers (no password) + AspNetUserRoles (Account)
3. Backend: Clerk API → invite user
4. Backend: INSERT tenant_users in control DB

### Role change
1. Admin changes role via admin UI → `PUT /api/v2/users/{id}/role`
2. Backend: UPDATE AspNetUserRoles
3. Backend: UPDATE tenant_users.role in control DB (denormalised copy)
4. ClerkUserResolutionMiddleware cache invalidated for that user
5. Next request picks up new role

### User lockout/ban
1. Admin bans user via admin UI
2. Backend: Clerk API → `POST /v1/users/{clerk_user_id}/ban`
3. Clerk refuses to issue JWT → user locked out immediately
4. No backend lockout check needed

---

## 8. What NOT to Do

- **Do NOT put roles in Clerk metadata** — roles are tenant-scoped business data
- **Do NOT add role claims to the Clerk JWT** — JWT should only carry `org_id` for tenant routing
- **Do NOT create new roles** without updating this contract and all 4 PRDs
- **Do NOT use magic role numbers in new code** — use `role` string or `permissions` object
- **Do NOT query UserManager for role checks** — use `HttpContext.Items["UserRole"]` (set by middleware)
- **Do NOT store role in localStorage** — call `/api/v2/users/me` and cache in app state

---

## 9. Driver-Context Pattern

Many admin and dispatch pages show a "driver dropdown" for admins and force
the logged-in driver's own data when a driver is logged in. This is a shared
pattern across v2b (admin rebuild), v2c (API endpoints), and v2d (dispatch).

### Frontend behaviour

| Role | What the user sees |
|------|--------------------|
| Admin / User | Dropdown to select any driver → passes `driverId` to API |
| Driver | No dropdown — API defaults to own data |

### Backend enforcement (v2c endpoints)

Every endpoint that accepts a `driverId` parameter must:

1. Read `UserRole` from `HttpContext.Items["UserRole"]`
2. Read `UserId` from `HttpContext.Items["UserId"]`
3. If role is **Driver**: ignore `driverId` param, force `driverId = UserId`
4. If role is **Admin** or **User**: use provided `driverId` param

**This is a security rule, not a convenience.** Drivers must never view or
modify another driver's data via parameter manipulation.

### Affected endpoint areas
- Availability (get, set, delete, log)
- Driver billing (chargeable jobs, statements, post jobs)
- Driver reporting (earnings, expenses)
- Any future driver-scoped endpoint

### GPS tracking exception
The GPS page (`/api/v2/drivers/gps`) is admin-only — it shows all driver
positions on a map. Drivers do not access this page.

---

## 10. Browser Notifications: FCM → Pusher

### Decision
Replace browser FCM notifications with Pusher events in both admin and dispatch.

### What stays
- `NotificationFCM` column on `AppUserProfiles` — this is **driver app mobile push**,
  completely separate from browser notifications. Do NOT touch this.
- Pusher tenant-scoped channels (PR #4) — already working

### What gets removed
- `ChromeFCM` column on `AppUserProfiles` — browser FCM token storage
- `UpdateBrowserFCM` / `RemoveBrowserFCM` API endpoints
- Firebase SDK from dispatch and admin apps
- FCM service workers

### What replaces it
- Pusher events → Browser `Notification` API (toast when tab is open)
- Audio alerts per event group with on/off toggle
- Audio settings stored in browser `localStorage` (per-browser, not per-tenant)
- No backend settings endpoint needed for audio — purely frontend

### Event groups

| Event group | Pusher event name | Sound type |
|------------|-------------------|------------|
| `driver_reject` | `booking.driver-rejected` | Alert tone |
| `driver_timeout` | `booking.driver-timeout` | Alert tone |
| `web_booking` | `booking.web-new` | Chime |
| `web_change` | `booking.web-change-request` | Chime |
| `booking_cancelled` | `booking.cancelled` | Warning tone |

### Who implements what
- **v2c** (API): removes `UpdateBrowserFCM`/`RemoveBrowserFCM`, does NOT create v2 equivalents
- **v2b** (admin rebuild): builds notification listener + settings UI using Pusher
- **v2d** (dispatch): replaces Firebase with Pusher notification listener + settings UI

---

*This contract must be approved before any v2 PRD implementation begins.
All 4 agents reference this document. Changes require updating all PRDs.*
