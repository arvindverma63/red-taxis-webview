# Red Taxi SaaS - Implementation Status

Last updated: 2026-04-14 (Session: WhatsApp chat widget shipped, WhatsApp metering now wired, UK business number +441747441405 live)

## Backend - 100% COMPLETE

Core backend SaaS work is complete including multi-tenant auth, provisioning, usage metering,
notification pipeline (Resend email + Webex SMS), and super-admin management endpoints.

### PRs Merged (11 total + 3 session commits)

| PR | Title | Date |
|----|-------|------|
| #1 | Phase A: Multi-tenant auth routing + provisioning + metering | 2026-03-29 |
| #2 | fix: provisioning seed timing + CompanyConfig NOT NULL | 2026-03-29 |
| #3 | Complete metering - all booking entry points + driver limits | 2026-03-29 |
| #4 | Pusher tenant isolation + new credentials | 2026-03-29 |
| #5 | fix: critical multi-tenant login resolution | 2026-03-29 |
| #6 | fix: tenant middleware thread safety + fail-closed login | 2026-03-29 |
| #7 | Webex SMS + SES email adapters with delivery status webhooks | 2026-03-29 |
| #8 | SaaS email service - 13 templates, swappable | 2026-03-29 |
| #9 | Codex security review - P0/P1/P2 fixes (24 files) | 2026-03-29 |
| — | Phase D: self-service onboarding, billing, settings | 2026-04-04 |
| — | Super-admin platform management (tenant list + detail + overrides) | 2026-04-04 |
| — | Wire SMS metering + driver count display | 2026-04-05 |

### Multi-Tenant Auth

| Item | Status | Verified |
|------|--------|----------|
| `tenant_users` table (login routing) | Yes | 2 users in 2 tenants |
| Login resolves tenant from request body | Yes | Test Taxis admin logs in successfully |
| JWT includes `tenant_org_id` claim | Yes | Decoded and confirmed |
| DbContext resolves per-request from JWT | Yes | Different data per tenant |
| ConcurrentDictionary for thread-safe caching | Yes | Codex review finding fixed |
| Login fails closed for unknown users | Yes | Documented behavior |
| Authenticated requests without tenant claim are rejected | Yes | Middleware hardened |

### Provisioning

| Item | Status | Verified |
|------|--------|----------|
| Creates tenant database | Yes | `redtaxi_test_taxis` created |
| Runs EF migrations | Yes | All tables created |
| Seeds AppRoles (4 roles) | Yes | Admin, User, Driver, Account |
| Seeds CompanyConfig (all NOT NULL columns) | Yes | 16 columns including CardTopupRate |
| Creates admin user with password | Yes | `admin@testtaxis.co.uk` |
| Creates AppUserProfiles | Yes | All NOT NULL columns |
| Assigns Admin role | Yes | AspNetUserRoles seeded |
| Registers in tenant_users (login routing) | Yes | Control DB updated |
| Seeds tenant_config (6 values) | Yes | CompanyName, Phone, etc. |
| Sets trial (7 days, no credit card) | Yes | active_trial status |
| Auto-provision on Stripe checkout.session.completed | Yes | Webhook triggers TenantProvisioningService |
| Self-provision fallback (POST /api/v2/tenants/self-provision) | Yes | Idempotent, checks payment first |
| TenantProvisioningService (shared, extracted) | Yes | Used by webhook + self-provision + super-admin |

### Usage Metering

| Counter | Limit Check | Increment/Decrement | Callers | Monthly Reset | Frontend Display | Status |
|---------|-------------|---------------------|---------|---------------|-----------------|--------|
| **Bookings** | `CanCreateBookingAsync` (429) | `IncrementBookingCountAsync` | 4 controllers (all create paths) | Yes (1st of month) | Progress bar X/Y + warning | **FULLY WIRED** |
| **Drivers** | `CanAddDriverAsync` (429) | Live count from tenant DB | 2 controllers (v1+v2 add) | N/A | Progress bar X/Y | **FULLY WIRED** |
| **SMS** | atomic via `TryConsumeSmsAsync` (reserve-then-send) | `TryConsumeSmsAsync` + `RefundSmsAsync` on failure (awaited), via ISmsUsageTracker | DirectNotificationOrchestrator | N/A | Balance number | **WIRED (atomic)** |
| **WhatsApp** | atomic via `TryConsumeWhatsAppAsync` (reserve-then-send); `CanSendWhatsAppAsync` read-only for /settings display | `TryConsumeWhatsAppAsync` + `RefundWhatsAppAsync` on failure (awaited), via IWhatsAppUsageTracker | WhatsApp dispatch path (DispatchService → MessagingService) | N/A | Balance number at /settings | **WIRED (atomic)** |
| **Address Lookups** | None | None | N/A | N/A | None | Manual — pending |

### Data Isolation (Proven)

| Data | Ace Taxis | Test Taxis | Demo Cabs |
|------|-----------|------------|-----------|
| Drivers | 30 | 1 | 0 |
| POIs | 450 | 0 | 0 |
| Bookings | 127,331 | 0 | 0 |
| Accounts | 51 | 0 | 0 |

### Real-Time (Pusher)

| Item | Status |
|------|--------|
| Tenant-scoped channels (`tenant-{orgId}`) | Yes |
| New Pusher account (app_id: 2134134) | Yes |
| Credentials in env vars | Yes |
| Frontend reads from `VITE_PUSHER_KEY` | Yes |

### Super-Admin Management

| Endpoint | Method | Purpose | Status |
|----------|--------|---------|--------|
| `GET /api/v2/tenants` | GET | List all tenants (enriched with usage/SMS/trial) | Working |
| `GET /api/v2/tenants/{orgId}` | GET | Tenant details + config (excludes database_url) | Working |
| `PATCH /api/v2/tenants/{orgId}` | PATCH | Update company profile | Working |
| `PUT /api/v2/super-admin/tenants/{orgId}/limits` | PUT | Override plan, max_drivers, max_bookings | Working |
| `PUT /api/v2/super-admin/tenants/{orgId}/usage` | PUT | Override bookings_used, sms_balance | Working |
| `PUT /api/v2/super-admin/tenants/{orgId}/status` | PUT | Change status, extend trial | Working |
| `PATCH /api/v2/tenant-status/onboarding` | PATCH | Mark onboarding complete | Working |
| `POST /api/v2/tenants/self-provision` | POST | Self-service provisioning (fallback) | Working |

Auth: `SuperAdminAuth.IsSuperAdmin()` — shared helper, checks `SUPER_ADMIN_ORG_ID` env var.

### Infrastructure

| Item | Status |
|------|--------|
| Control DB on Railway | Yes - 3 tenants, 37+ configs each |
| Railway env vars (10 SaaS vars) | Yes |
| Resend email (SaaS templates) | Yes — domain verified, 13 templates |
| Webex SMS (sole provider) | Yes — webhook confirmed |
| Stripe products (14) + prices (16) | Yes |
| Clerk test mode configured | Yes — 42 users + 2 orgs |
| TenantProvisioningService | Yes — shared by webhook, self-provision, super-admin |
| ISmsUsageTracker interface | Yes — in RedTaxi.Shared, implemented by UsageMeteringService |

### Notification Pipeline

| Channel | Provider | Route | Status Tracking | Verified |
|---------|----------|-------|----------------|----------|
| SaaS email (13 templates) | Resend | `ResendEmailService` | Webhook events (8 types) | Yes |
| Operational email (15 templates) | Resend | `ResendTemplateEmailService` (SendGrid removed 2026-04-09) | Delivery log | Yes |
| Email (backup) | AWS SES | `SesEmailAdapter` (toggle via `EMAIL_PROVIDER=ses`) | SNS → NotificationLog | Built |
| SMS | Webex Interact | `WebexSmsAdapter` via `DirectNotificationOrchestrator` | Delivery callback | Yes |
| SMS metering | ISmsUsageTracker | `DirectNotificationOrchestrator` → atomic `TryConsumeSmsAsync` (reserve-then-send) + `RefundSmsAsync` on failure | Control DB | Yes |
| Push | Pusher (browser) | `PusherService` | N/A | Yes |
| WhatsApp | Twilio | `MessageService` (legacy) | No | Pending manual wiring |

### Known Issues

| Issue | Severity | Action |
|-------|----------|--------|
| Legacy `SendSmsAsync` base class still calls dead TextLocal API | Low | Clean up in next refactor |
| WhatsApp messages unmetered | Medium | Owner handling manually |
| Address lookups unmetered | Medium | Owner handling manually |
| 31 account-level ACE-SPECIFIC hardcodes remain | Low | Phase 4b |

## Frontend - COMPLETE (Phase D)

### SaaS Admin App (`src/frontend/apps/saas-admin/`)

| # | Page | Route | Status |
|---|------|-------|--------|
| 1 | Landing page | `/` | Live |
| 2 | Sign in / Sign up | `/sign-in`, `/sign-up` | Live (Clerk) |
| 3 | Onboarding wizard | `/onboarding` | Live — 3-step: Company → Plan → Stripe Checkout |
| 4 | Onboarding success | `/onboarding/success` | Live — polls provisioning, self-provision fallback |
| 5 | Dashboard | `/dashboard` | Live — tenant status, usage cards (bookings + drivers + SMS), banners, quick actions, notifications |
| 6 | Billing | `/dashboard/billing` | Live — BillingDashboard: current plan, usage, Stripe portal, plan comparison |
| 7 | Settings | `/dashboard/settings` | Live — company profile (save wired), billing card, Clerk team management |
| 8 | Platform Admin - Tenant List | `/dashboard/admin` | Live — table with badges, progress bars, quick actions (lock/unlock/extend) |
| 9 | Platform Admin - Tenant Detail | `/dashboard/admin/[orgId]` | Live — 4 editable cards (profile, limits, usage, status) + read-only config |
| 10 | Platform Admin - Plans | `/dashboard/admin/plans` | Live — editable table, Stripe auto-sync on price changes |
| 11 | Organization selection | `/onboarding/organization-selection` | Live (Clerk) |

### Key Components

- **TenantBanner** — trial warning (blue), grace period (yellow), soft lock (red), hard lock (overlay modal)
- **UsageCards** — bookings progress bar (X/Y), drivers progress bar (X/Y), SMS balance
- **BillingDashboard** — current plan badge, usage bars, Stripe portal link, plan comparison cards
- **CompanyHeader** — company name + plan badge + status badge
- **QuickActions** — dispatch console + admin panel links
- **DashboardHeader** — conditional "Platform Admin" nav item for super-admin org

### API Client (`src/lib/api.ts`)

| Function | Endpoint | Purpose |
|----------|----------|---------|
| `fetchTenantStatus` | GET /api/v2/tenant-status | Dashboard data + banners |
| `fetchSubscription` | GET /api/v2/billing/subscription | Plan + limits |
| `createCheckout` | POST /api/v2/billing/create-checkout | Stripe checkout session |
| `createBillingPortal` | POST /api/v2/billing/create-portal | Stripe portal URL |
| `selfProvision` | POST /api/v2/tenants/self-provision | Fallback provisioning |
| `markOnboardingComplete` | PATCH /api/v2/tenant-status/onboarding | Complete onboarding |
| `fetchTenantDetails` | GET /api/v2/tenants/{orgId} | Full tenant + config |
| `updateTenantProfile` | PATCH /api/v2/tenants/{orgId} | Update company profile |
| `fetchAllTenants` | GET /api/v2/tenants | List all (super-admin) |
| `updateTenantLimits` | PUT super-admin/.../limits | Override plan/limits |
| `updateTenantUsage` | PUT super-admin/.../usage | Override usage counters |
| `updateTenantStatusAdmin` | PUT super-admin/.../status | Change status/trial |
| `fetchPlans` | GET /api/v2/plans | Public plans list (pricing pages) |
| `fetchAdminPlans` | GET /api/v2/super-admin/plans | All plans with Stripe IDs |
| `updatePlan` | PUT /api/v2/super-admin/plans/{id} | Update plan + Stripe sync |
| `resolveToken` | /dev/token (dev mode) | Dev token fallback for local testing |

## Auth Consolidation (v2a) — Step 2.2 Complete

Last updated: 2026-03-30

### What's Done

| Phase | Status |
|-------|--------|
| 1.1 ClerkUserId column + EF migration | Complete |
| 1.2 Clerk org + user backfill (test mode) | Complete — 42/42 users, virtual emails |
| 1.3 CurrentUserMiddleware | Complete |
| 2.1 Handlers (8 files) — UserManager removed | Complete |
| 2.2 Controllers (6 files) — User.Identity.Name/IsInRole removed | Complete |
| 2.3 UserProfileService — UserManager replacement | Blocked (needs Phase 3) |
| 2.4 UsersService — UserManager replacement | Blocked (needs Phase 3) |
| 3 Frontend Clerk migration | Not started |
| 4 Legacy auth removal | Not started (needs Phase 3) |

## Admin v2 Frontend — 64 ROUTES LIVE (COMPLETE)

Last updated: 2026-04-07

Located at `src/frontend/apps/admin-v2/`. Next.js 16 + React 19 + Clerk + TanStack Query.

New in this session:
- `/settings/users` — Operator user management: CRUD, role assignment, soft-delete/restore, lockout
- `/settings/address` — Address & Maps: provider toggle (Ideal/Google), interactive map pickers, map style (6 themes), zoom slider, postcode filters, SMS sender ID, review URL
- `/school-tariffs` — School Contract Tariffs: CRUD with per-mile rates, discount, surcharges, waiting charges, postcode exclusion
- `/tariffs` — renamed to "Cash Tariffs", added Pricing Rules card (minimum fare + 5+ seater surcharge)
- Account form: Contract Type dropdown (Standard/School Contract) + tariff assignment per type
- Account list: "School" badge on school contract accounts
- Account Tariffs: added waiting time fields (driver + account £/min)
- Driver form: per-driver Rank Commission % (decimal, replaces global config)
- Company Settings: Add VAT on Card Payments toggle
- Branded Clerk sign-in page (dark theme, RT logo, red accents)
- Maps: shared style system (lib/map-styles.ts), tracking + heatmap use tenant's saved style

## Production Deploy — COMPLETE

Deployed 2026-04-05:
- Merged `feature/admin-v2-scaffold` → `dev` → `main` (25 commits)
- Railway API auto-deployed and healthy at `api.redtaxi.co.uk`
- Vercel frontends deployed (4 projects with `ignoreCommand` scoped per-app)
- Plans table migrated on production control DB (4 plans seeded)
- Env vars set: `SUPER_ADMIN_ORG_ID` (Railway), `NEXT_PUBLIC_SUPER_ADMIN_ORG_ID` + `CLERK_SECRET_KEY` (Vercel saas)
- Stale `saas-admin` Vercel project deleted (orphan duplicate)
- Shell project removed from codebase (admin-v2 is single app at app.redtaxi.co.uk)

## To Resume

1. ~~**HVS Sub-project 4**~~ — **DONE.** All pricing routing uses ContractType.
2. ~~**Remaining pricing settings**~~ — **DONE.** Per-tariff waiting charges, HVS discount from entity, no global fallback.
3. **Swap auth on headless-dispatch + account-booker** — migrate from v1 internal JWT to Clerk auth. Admin v1 is retired. Mobile apps still need v1 password login. See handoff below.
4. **WhatsApp metering** — owner handling manually
5. **Address lookup metering** — owner handling manually
6. **Bolt-on add-ons** — SMS packs, extra drivers, web booking portal from super-admin
7. **Playwright e2e tests** — admin-v2 + saas-admin
8. **Production Clerk instance** — switch from test mode when ready for real customers
9. **Frontend dispatch map changes** — see `docs/frontend-dispatch-changes.md`

## Auth Consolidation (v2a) — Phases 1-3 COMPLETE

Completed 2026-04-06.

### What's Done
- **Phase 1:** ClerkUserId column + backfill + CurrentUserMiddleware ✅
- **Phase 2:** UserManager read-only calls replaced with direct EF queries across 6 files ✅
  - 3 list handlers (OperatorsList, OperatorsListDeleted, DriversListDeleted): N+1 GetRolesAsync fixed with batch join
  - UsersService + UserProfileService: FindByName, FindById, GetRolesAsync, FindByEmailAsync all direct DB
  - Program.cs /dev/token: direct DB queries
- **Phase 3:** All 4 frontends migrated to Clerk ✅
  - headless-dispatch: hybrid mode (Clerk standalone + iframe postMessage + dev token)
  - account-booker: full Clerk migration, Redux auth removed, axios interceptor added
  - admin-v2 + saas-admin: already on Clerk (no changes)
  - See `docs/frontend-auth-status.md` for full status

### What's Left (Phase 4)
- Remove Internal JWT scheme from Program.cs MultiAuth
- Delete: AuthenticationService, JwtMiddleware, legacy login handlers
- Drop: AppRefreshTokens table
- Blocked until mobile apps (external repo) migrate to Clerk
- Est. effort: 2-3h

## Settings Migration — COMPLETE

Completed 2026-04-06.

- Operational settings moved from `tenant_config` (control DB) → `TenantSettings` (tenant DB)
- New DispatchConfig entity for dispatch-specific settings (MinimumDuration)
- ITenantConfigService interface unchanged — 14 consumer files untouched
- SubmitTicket handler removed (replacing support with new system)
