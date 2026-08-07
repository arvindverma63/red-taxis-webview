# Red Taxi — PRD v2a: Auth Consolidation

**Version:** 1.1
**Status:** Phases 1-3 COMPLETE (2026-04-06). Phase 4 pending (blocked by mobile apps).
**Author:** Red Banana Studios
**Created:** 2026-03-29
**Depends on:** PRD v1.2 (complete), SaaS backend (complete)
**Parallel with:** PRD v2b (Admin Frontend Rebuild)

> This PRD can be executed by a Codex agent. It is backend-focused and does not
> touch admin page logic. PRD v2b (admin rebuild) depends on the Clerk auth
> contract defined here but can start in parallel.

---

## 1. Objective

Consolidate the dual auth system (Internal HS256 JWT + Clerk RS256 JWT) into
**Clerk-only authentication** for all user types across all frontends.

### Why now
- We're about to rebuild the admin frontend (PRD v2b) — building it on Clerk
  from day 1 avoids doing auth work twice.
- The dual auth system (MultiAuth policy with algorithm sniffing) is fragile
  and doubles the auth surface area.
- Legacy JWT stores passwords in `AppUsers.PasswordHash` and refresh tokens in
  `AppRefreshTokens` — unnecessary attack surface when Clerk handles all of this.

### What this does NOT do
- Does not change any business logic or API response shapes
- Does not touch booking, dispatch, billing, or reporting handlers
- Does not remove the `AppUsers` table (it holds business FKs)
- Does not touch `UserProfile`/`DriverProfile` data (GPS, vehicle, FCM, commission)

---

## 2. Current State

### Dual Auth Architecture
```
Frontend sends JWT in Authorization header
    ↓
MultiAuth policy (Program.cs:195-221)
    ├─ Reads JWT header
    ├─ RS256 → Clerk scheme (validates against Clerk JWKS)
    └─ HS256 → Internal scheme (validates against JWT_SECRET_KEY)
    ↓
TenantResolutionMiddleware
    ├─ Reads tenant_org_id from JWT claims
    ├─ For login requests: queries control DB tenant_users by username
    └─ Resolves tenant connection string
    ↓
JwtMiddleware (for Internal JWT only)
    ├─ Extracts user ID from "id" claim
    ├─ Looks up AppUser by ID
    ├─ Checks lockout status
    └─ Attaches user to HttpContext.Items["User"]
```

### User Types and What's Stored Locally

| Role | AppUser fields used | UserProfile fields used | Needs local record? |
|------|-------------------|----------------------|-------------------|
| **Driver** | Id, UserName, FullName, Email, Phone | GPS, Vehicle, RegNo, FCM, Commission, VehicleType, CommsPlatform | **Yes** — business-critical |
| **Account** | Id, UserName, FullName, Email | None (no UserProfile row) | **Slim** — just FK target |
| **Admin** | Id, UserName, FullName, Email | None meaningful | **Slim** — just FK target |
| **User** (staff) | Id, UserName, FullName, Email | ShowAllBookings, ShowHVSBookings | **Slim** — just FK + prefs |

### Files That Reference UserManager (15 total)

**Controllers (5):**
- `RedTaxi.API/Controllers/AccountsController.cs`
- `RedTaxi.API/Controllers/AdminUIController.cs`
- `RedTaxi.API/Controllers/BookingsController.cs`
- `RedTaxi.API/Controllers/DriverAppController.cs`
- `RedTaxi.API/Controllers/WeBookingController.cs`

**Handlers (8):**
- `Features/AdminUI/DriverUpdate.cs`
- `Features/Bookings/RefundPayment.cs`
- `Features/Bookings/SendConfirmationText.cs`
- `Features/Bookings/SendPaymentLink.cs`
- `Features/Bookings/SendPaymentReceipt.cs`
- `Features/Bookings/SendQuote.cs`
- `Features/Bookings/ResendPaymentLink.cs`
- `Features/Messaging/SendTextMessage.cs`

**Services (2):**
- `Services/Auth/UsersService.cs`
- `Services/UserProfileService.cs`

---

## 3. Target State

### Single Auth Architecture
```
Frontend sends Clerk JWT in Authorization header
    ↓
Standard Clerk JWT validation (RS256, JWKS auto-discovery)
    ↓
TenantResolutionMiddleware (simplified)
    ├─ Reads tenant_org_id from Clerk org_id claim
    └─ Resolves tenant connection string (same as today)
    ↓
ClerkUserResolutionMiddleware (NEW)
    ├─ Reads Clerk user_id from JWT sub claim
    ├─ Looks up AppUsers.ClerkUserId → AppUsers.Id
    ├─ Attaches UserId (int) to HttpContext.Items["UserId"]
    └─ Attaches UserRole to HttpContext.Items["UserRole"]
```

### Schema Changes

**AppUsers table — columns to ADD:**
```sql
ALTER TABLE "AppUsers" ADD COLUMN "ClerkUserId" VARCHAR(64) NULL;
CREATE UNIQUE INDEX "IX_AppUsers_ClerkUserId" ON "AppUsers" ("ClerkUserId");
```

**AppUsers table — columns that become UNUSED (null out, remove later):**
- `PasswordHash` — Clerk owns passwords
- `SecurityStamp` — Identity machinery
- `ConcurrencyStamp` — Identity machinery
- `AccessFailedCount` — Clerk handles lockout
- `LockoutEnd` — Clerk handles lockout
- `LockoutEnabled` — Clerk handles lockout
- `TwoFactorEnabled` — Clerk handles 2FA
- `PhoneNumberConfirmed` — Clerk handles verification
- `EmailConfirmed` — Clerk handles verification

**Tables to DROP (migration):**
- `AppRefreshTokens` — Clerk handles token refresh
- `AppUserTokens` — Identity token store, unused
- `AppUserLogins` — Identity external logins, unused
- `AppUserClaims` — Identity claims, unused
- `AppRoleClaims` — Identity role claims, unused

**Tables to KEEP:**
- `AppUsers` — business FK target (Id, ClerkUserId, UserName, FullName, Email, PhoneNumber)
- `AppUserProfiles` — driver business data (GPS, vehicle, commission, FCM)
- `AppRoles` — role definitions (Admin=1, User=2, Driver=3, Account=4)
- `AspNetUserRoles` — role assignments (UserId → RoleId)

---

## 4. Implementation Plan

### Phase 1: Add ClerkUserId + Migration (no breaking changes)

**Step 1.1 — EF Migration: Add ClerkUserId column**
- Add `ClerkUserId` (string, nullable, unique index) to `AppUser` entity
- Generate and apply EF migration
- No existing data affected

**Step 1.2 — Backfill ClerkUserId for Ace Taxis users**
- Create Ace Taxis organization in Clerk (production)
- Invite all Ace Taxis users (operators + drivers) to Clerk org
- Write a one-time backfill script that maps Clerk user IDs to AppUsers by email match
- Update `ClerkUserId` column for each matched user
- Update `tenant_users` table in control DB with Clerk user references

**Step 1.3 — Add ClerkUserResolutionMiddleware**
- New middleware that runs after auth + tenant resolution
- For Clerk JWTs: reads `sub` claim → looks up `AppUsers.ClerkUserId` → sets `HttpContext.Items["UserId"]`
- For Internal JWTs: reads `id` claim → sets `HttpContext.Items["UserId"]` (backwards compatible)
- Cache the ClerkUserId→Id mapping in-memory (ConcurrentDictionary, same pattern as tenant cache)

**Deliverable:** Both auth schemes work. Clerk users get resolved to the same int UserId. Zero breaking changes.

---

### Phase 2: Replace UserManager with direct queries

**Step 2.1 — Replace UserManager in 8 handlers**

All 8 handlers use `UserManager<AppUser>` for exactly one thing: `FindByNameAsync(username)`.
Replace with direct EF query:

```csharp
// Before
var user = await _userManager.FindByNameAsync(request.Username);

// After
var user = await _db.Users.FirstOrDefaultAsync(u => u.UserName == request.Username);
```

Files to change:
1. `Features/AdminUI/DriverUpdate.cs`
2. `Features/Bookings/RefundPayment.cs`
3. `Features/Bookings/SendConfirmationText.cs`
4. `Features/Bookings/SendPaymentLink.cs`
5. `Features/Bookings/SendPaymentReceipt.cs`
6. `Features/Bookings/SendQuote.cs`
7. `Features/Bookings/ResendPaymentLink.cs`
8. `Features/Messaging/SendTextMessage.cs`

**Step 2.2 — Replace UserManager in 5 controllers**

Controllers inject `UserManager<AppUser>` for resolving the current user from JWT claims.
Replace with `HttpContext.Items["UserId"]` (set by ClerkUserResolutionMiddleware).

Files to change:
1. `Controllers/AccountsController.cs`
2. `Controllers/AdminUIController.cs`
3. `Controllers/BookingsController.cs`
4. `Controllers/DriverAppController.cs`
5. `Controllers/WeBookingController.cs`

**Step 2.3 — Replace UserManager in UserProfileService**

`UserProfileService` uses UserManager for:
- `CreateAsync(user, password)` → Replace with direct INSERT + no password (Clerk-invited users)
- `AddToRoleAsync(user, role)` → Replace with direct INSERT into AspNetUserRoles
- `CheckPassword(user, password)` → Remove entirely (Clerk validates passwords)
- `FindByEmailAsync(email)` → Replace with `_db.Users.FirstOrDefaultAsync(u => u.Email == email)`
- `GeneratePasswordResetTokenAsync` / `ResetPasswordAsync` → Remove (Clerk handles password reset)
- `LockoutOnOff` → Replace with Clerk user suspension API or simple bool flag

**Step 2.4 — Replace UserManager/RoleManager in UsersService**

`UsersService` is the primary auth wrapper. Most methods become dead code:
- `FindByUsernamePassword()` → Remove (Clerk validates credentials)
- `CheckPassword()` → Remove
- `Create()` → Replace with direct INSERT
- `FindByName()` / `FindById()` → Replace with direct EF queries
- `GetUserRoles()` → Replace with direct query on AspNetUserRoles + AppRoles
- `LockoutOnOff()` → Replace with Clerk API or simple flag

**Deliverable:** Zero references to `UserManager<AppUser>` or `RoleManager<AppRole>` in the codebase.

---

### Phase 3: Update frontends to Clerk

**Step 3.1 — Update dispatch app**
- Replace custom `AuthContext.jsx` + localStorage JWT with Clerk `<SignIn />`
- Replace `Protected` route wrapper with Clerk `useAuth()` guard
- Remove iframe postMessage token passing (no longer needed — Clerk handles cross-domain)
- Clerk `useAuth().getToken()` provides the Bearer token for API calls

**Step 3.2 — Update driver app**
- Replace legacy login form (POST `/api/driverapp/login`) with Clerk `<SignIn />`
- Clerk JWT automatically includes `org_id` for tenant routing
- Driver-specific data (GPS, FCM) continues to POST to existing endpoints

**Step 3.3 — Update admin app (or skip if PRD v2b rebuilds it)**
- If PRD v2b is running in parallel, the new admin is already on Clerk — skip this
- If admin rebuild hasn't started yet, swap auth layer in existing admin:
  - Replace Redux authSlice + localStorage JWT with Clerk
  - Replace RequireAuth wrapper with Clerk guard
  - Replace login/signup pages with Clerk components

**Step 3.4 — Account booker app**
- Replace auth with Clerk (account users authenticate via Clerk org invitation)

**Deliverable:** All frontends authenticate via Clerk. No frontend sends HS256 JWT.

---

### Phase 4: Remove legacy auth machinery

**Step 4.1 — Remove Internal JWT scheme from Program.cs**
- Remove `AddJwtBearer("Internal", ...)` (lines 162-165)
- Remove `AddPolicyScheme("MultiAuth", ...)` (lines 195-221)
- Keep only `AddJwtBearer("Clerk", ...)` as the default scheme
- Remove `AddDefaultIdentity<AppUser>().AddRoles<AppRole>()` (line 121)

**Step 4.2 — Delete auth files**
- Delete `Services/Auth/AuthenticationService.cs` — JWT generation, token refresh
- Delete `Services/Auth/JwtMiddleware.cs` — legacy token validation
- Delete `Services/Auth/UsersService.cs` — if fully replaced by direct queries
- Delete `Features/UserProfile/LoginUser.cs` — legacy login handler
- Delete `Features/UserProfile/RefreshToken.cs` — legacy refresh handler
- Delete `Features/UserProfile/ResetPassword.cs` — Clerk handles this
- Delete `Features/UserProfile/RegisterUser.cs` — Clerk handles user creation

**Step 4.3 — Remove login endpoints**
- Remove `POST /api/userprofile/login` route
- Remove `POST /api/v2/users/login` route
- Remove `POST /api/driverapp/login` route from TenantResolutionMiddleware detection

**Step 4.4 — Simplify TenantResolutionMiddleware**
- Remove login body parsing logic (lines 70-93) — no more login requests to sniff
- Remove `_userTenantCache` — all requests have Clerk JWT with org_id
- Middleware becomes: read `tenant_org_id` from JWT → resolve connection string

**Step 4.5 — EF Migration: Drop unused tables**
```sql
DROP TABLE "AppRefreshTokens";
DROP TABLE "AppUserTokens";
DROP TABLE "AppUserLogins";
DROP TABLE "AppUserClaims";
DROP TABLE "AppRoleClaims";
```

**Step 4.6 — Null out unused AppUser columns**
```sql
UPDATE "AppUsers" SET
    "PasswordHash" = NULL,
    "SecurityStamp" = NULL,
    "ConcurrencyStamp" = NULL,
    "AccessFailedCount" = 0,
    "LockoutEnd" = NULL;
```

Optionally drop these columns in a future migration once stable.

**Step 4.7 — Remove NuGet packages**
- Remove `Microsoft.AspNetCore.Identity.EntityFrameworkCore` (if no longer needed after AppDbContext adjusted)
- Or keep it if `IdentityDbContext` base class is still convenient for the User/Role tables

**Deliverable:** Single auth scheme. No Internal JWT code path. No password storage. No refresh token management.

---

## 5. Driver Onboarding — New Flow

Current flow (legacy):
1. Admin creates driver via `/api/AdminUI/DriverAdd`
2. `UserProfileService.Create()` → `UserManager.CreateAsync(user, password)`
3. Password emailed to driver
4. Driver logs in with username/password → gets Internal JWT

New flow (Clerk):
1. Admin creates driver in admin UI (PRD v2b)
2. Backend creates AppUser row (no password) + UserProfile row
3. Backend calls Clerk API: `POST /v1/organizations/{org_id}/invitations` with driver email + role
4. Driver receives Clerk invitation email → sets own password
5. Driver logs in via Clerk → gets RS256 JWT with org_id
6. ClerkUserResolutionMiddleware maps Clerk sub → AppUser.Id

### Account User Onboarding — Same Pattern
1. Admin registers account web booker via admin UI
2. Backend creates AppUser row (no password)
3. Backend invites via Clerk API
4. Account user sets own password via Clerk

---

## 6. Password Reset — New Flow

Current flow:
1. Admin clicks "Reset Password" for a user
2. `UserProfileService.ChangePassword()` generates a predictable password (`{prefix}{hour}{minute}`)
3. Password emailed in plaintext

New flow:
1. Admin clicks "Reset Password" in admin UI
2. Backend calls Clerk API: `POST /v1/users/{clerk_user_id}/reset_password`
3. Clerk sends secure password reset email
4. User resets own password via Clerk hosted page

**Security improvement:** No more predictable passwords. No more plaintext passwords in emails.

---

## 7. Lockout — New Flow

Current flow:
- `UserProfileService.LockoutOnOff()` sets `LockoutEnd` to 5 years in the future via Identity
- `JwtMiddleware` checks lockout status on every request

New flow:
- Backend calls Clerk API: `POST /v1/users/{clerk_user_id}/ban` or `/unban`
- Clerk refuses to issue JWT for banned users
- No backend lockout check needed — banned users can't get a valid token

---

## 8. Risk Mitigation

### Rollback Plan
- Phase 1-2 are **non-breaking** — both auth schemes work simultaneously
- Phase 3 deploys one frontend at a time — roll back by reverting the Vercel deployment
- Phase 4 is the point of no return — only execute after all frontends confirmed working on Clerk
- Keep `JwtMiddleware` and `AuthenticationService` in a `_deprecated/` folder for 2 weeks before deleting

### Migration Window
- Ace Taxis operators work shifts — schedule Clerk invitation emails for a quiet period
- Drivers should receive invitations with clear instructions ("Set your new password")
- Keep Internal JWT valid for 7 days after Clerk invitations sent (overlap period)
- Monitor: any request still using HS256 JWT after cutoff date → alert

### Testing Checklist
- [ ] Clerk org created for Ace Taxis
- [ ] All Ace users invited to Clerk
- [ ] ClerkUserId backfilled for all AppUsers
- [ ] Dispatch app works with Clerk JWT
- [ ] Driver app works with Clerk JWT
- [ ] Admin app works with Clerk JWT (or new admin from v2b)
- [ ] Account booker works with Clerk JWT
- [ ] GPS updates work for drivers via Clerk JWT
- [ ] FCM token updates work via Clerk JWT
- [ ] Driver add/edit flow works with Clerk invitation
- [ ] Password reset via Clerk works
- [ ] Lockout/ban via Clerk works
- [ ] All 244 snapshot tests pass
- [ ] Internal JWT scheme removed
- [ ] AppRefreshTokens table dropped
- [ ] No HS256 tokens observed in production logs for 48 hours

---

## 9. Effort Estimate

| Phase | Effort | Can parallelise with v2b? |
|-------|--------|--------------------------|
| Phase 1: Add ClerkUserId + backfill | 3-4 hours | Yes — no breaking changes |
| Phase 2: Replace UserManager | 3-4 hours | Yes — no breaking changes |
| Phase 3: Update frontends | 4-6 hours | Yes — one app at a time |
| Phase 4: Remove legacy auth | 2-3 hours | After Phase 3 verified |
| **Total** | **12-17 hours** | |

---

## 10. Interface Contract (for PRD v2b, v2c, v2d)

See `docs/shared-contract-roles.md` for the full shared contract. Summary:

```
Auth provider:     Clerk
JWT type:          RS256
Org claim:         org_id → mapped to tenant_org_id
User claim:        sub → mapped to AppUser.Id via ClerkUserId lookup
Role source:       Tenant DB (AspNetUserRoles) — NOT Clerk
Role delivery:     GET /api/v2/users/me → { role, roleId, permissions }
Token retrieval:   useAuth().getToken() (Clerk React SDK)
Backend access:    HttpContext.Items["UserId"], ["UserRole"], ["UserRoleId"]
```

**Key decision:** Clerk owns identity (auth, passwords, MFA). Tenant DB owns roles
(Admin=1, User=2, Driver=3, Account=4). Roles are tenant-scoped business data,
not identity data. See shared contract for full rationale.

PRD v2b can start building immediately using Clerk test mode. The real Clerk org
and user backfill (Phase 1.2) only needs to be done before production deployment.

---

## 11. Non-Negotiable Rules

All rules from PRD v1.2 carry forward. Additionally:

- No passwords stored in `AppUsers` after migration
- No predictable password generation (current `{prefix}{hour}{minute}` pattern is a security risk)
- No plaintext passwords in emails
- No dual auth after Phase 4 is complete — Clerk is the single source of truth
- `AppUser.Id` (int) remains the internal FK everywhere — never use ClerkUserId as a FK
- `UserProfile` data (GPS, vehicle, FCM, commission) is business data, not auth — it stays

---

*This document is a draft. Approve before any implementation begins.*
