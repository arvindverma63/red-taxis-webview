# Red Taxi — PRD v2 (DRAFT)

**Version:** 2.0-draft
**Status:** Draft — not yet approved for implementation
**Author:** Red Banana Studios
**Created:** 2026-03-29
**Depends on:** PRD v1.2 (locked, complete)

> This document is a DRAFT. Nothing here should be implemented until approved.
> Implementation may be handled by separate Codex agents building features for integration.

---

## 1. Context

PRD v1.2 is complete. The platform is:
- Live in production (Ace Taxis operating daily)
- Multi-tenant SaaS backend complete (separate DB per tenant, Clerk auth, Stripe billing)
- SaaS frontend v1 complete (landing, dashboard, onboarding, settings, billing)
- 244 snapshot tests passing
- 230+ MediatR handlers across 16 feature areas

### What's still open from SaaS launch
These are **pre-requisites** before PRD v2 work begins:

| Item | Status | Owner |
|------|--------|-------|
| SES out of sandbox (production email) | Pending | AWS console |
| Full end-to-end signup test | Pending | Manual |
| Stripe webhook end-to-end test | Pending | Manual |
| Trial lifecycle test (banner transitions) | Pending | Manual (DB date manipulation) |
| Frontend v1 redesign handoff | Pending | Replit/Loveable |
| Webex Interact verification (SMS) | Pending | Webex |

---

## 2. Shared Contract: Roles & User Identity

**All v2 PRDs build against a shared contract.** See `docs/shared-contract-roles.md`.

Summary:
- **Clerk** owns identity (auth, passwords, MFA, email verification)
- **Tenant DB** owns roles (Admin=1, User=2, Driver=3, Account=4) in `AspNetUserRoles`
- **`GET /api/v2/users/me`** is the single endpoint for user + role + permissions
- **`HttpContext.Items["UserId"]` / `["UserRole"]`** is how backend code accesses user context
- No magic role numbers in new code — use `permissions` object or `role` string

---

## 3. PRD v2 Tracks — 4 Parallel Workstreams

### PRD v2a: Auth Consolidation (Backend — Codex Agent A)

Migrate all auth to Clerk. Remove legacy JWT/Identity machinery.

See `docs/prd-v2a-auth-consolidation.md` for full detail.

| Phase | What | Effort |
|-------|------|--------|
| 1 | Add ClerkUserId to AppUsers + backfill Ace users | 3-4h |
| 2 | Replace UserManager with direct EF queries (15 files) | 3-4h |
| 3 | Update frontends to Clerk (dispatch, driver, admin, account booker) | 4-6h |
| 4 | Remove Internal JWT, AuthenticationService, JwtMiddleware, AppRefreshTokens | 2-3h |
| **Total** | | **12-17h** |

**Produces:** `ClerkUserResolutionMiddleware`, `GET /api/v2/users/me`, ClerkUserId mapping

### PRD v2b: Admin Frontend Rebuild (Frontend — Codex Agent B / Replit)

Replace 88K-line admin app with clean ~15K-line build.

See `docs/prd-v2b-admin-rebuild.md` and `docs/admin-rebuild-inventory.md` for full detail.

| Phase | What | Effort |
|-------|------|--------|
| 1 | Scaffold + Clerk auth + layout + shared components | 1-2 days |
| 2 | 22 read-only pages (reports, history, lists) | 2-3 days |
| 3 | 18 medium CRUD pages (drivers, accounts, bookings) | 2-3 days |
| 4 | 5 complex pages (invoice processor, statement processing, booking form, tracking) | 3-5 days |
| 5 | Polish + Playwright tests + deploy | 1-2 days |
| **Total** | | **9-14 days** |

**Consumes:** `GET /api/v2/users/me` (from v2a), v2 endpoints (from v2c)

### PRD v2c: v2 API Completion (Backend — Codex Agent C)

Create the 60 missing v2 endpoints that the admin rebuild needs.

See endpoint inventory in `docs/prd-v2b-admin-rebuild.md` Section 4.

| Priority | Area | Endpoints | Effort |
|----------|------|----------|--------|
| 1 | Drivers, POI, availability, settings, dashboard, booking views | ~25 endpoints | 12-15h |
| 2 | Billing (statements, invoices, credits, VAT) | ~20 endpoints | 10-12h |
| 3 | Web bookings, GPS, FCM, messaging, utilities | ~15 endpoints | 5-8h |
| **Total** | | **~60 endpoints** | **25-30h** |

All endpoints follow the existing pattern: MediatR handler → v2 controller route →
`{ success, data, errors }` envelope → snapshot test. **No new business logic** —
the handlers already exist, called by v1 controllers today.

**Consumes:** `HttpContext.Items["UserRole"]` (from v2a) for role-gated endpoints

### PRD v2d: Dispatch Auth Swap (Frontend — Codex Agent D)

Swap dispatch app auth from legacy JWT to Clerk. No page logic changes.

| Step | What | Effort |
|------|------|--------|
| 1 | Replace AuthContext.jsx with Clerk `<SignIn />` | 1-2h |
| 2 | Replace Protected wrapper with Clerk `useAuth()` guard | 1h |
| 3 | Remove iframe postMessage token passing | 30m |
| 4 | Call `/api/v2/users/me` on load, store roleId for existing checks | 1h |
| 5 | Test all dispatch flows with Clerk JWT | 2-3h |
| **Total** | | **5-7h** |

**Consumes:** `GET /api/v2/users/me` (from v2a), keeps `roleId` (int) for existing `roleId !== 3` checks

---

## 4. Dependency Graph

```
shared-contract-roles.md (approve first)
    ↓
PRD v2a (auth)──────────────────────────────┐
    │                                        │
    ├─ Phase 1 (ClerkUserId + /users/me) ───┤
    │                                        │
PRD v2c (v2 endpoints) ─────────────────┐   │
    │ (no auth dependency,              │   │
    │  can start immediately)           │   │
    │                                    │   │
    ↓                                    ↓   ↓
PRD v2b (admin rebuild) ◄──── needs v2 endpoints + /users/me
                                         │
PRD v2d (dispatch auth) ◄──── needs v2a Phase 1 only
```

**v2a and v2c can start day 1** — they touch different files (auth vs controllers).
**v2b can start day 1** — scaffold + read-only pages using existing v2 endpoints.
**v2d starts after v2a Phase 1** — needs ClerkUserId + /users/me to exist.

---

## 5. Future Tracks (not in this sprint)

### Track E: Revenue Mechanics

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| E1 | Upgrade/downgrade plan flow | 2-3h | Stripe proration, plan change API + UI |
| E2 | SMS pack bolt-on purchasing | 2-3h | Metering built, needs Stripe product + purchase UI |
| E3 | WhatsApp metered billing | 2h | WATI integration exists, needs usage tracking + billing |
| E4 | Annual billing discount | 1h | Stripe supports this, needs pricing page update |
| E5 | Exit survey at soft lock | 1h | Capture churn reasons before hard lock |

### Track F: Admin Visibility

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| F1 | Super-admin dashboard | 3-4h | Tenant list, revenue, usage, health across all tenants |
| F2 | Tenant health alerts | 2h | Auto-flag tenants with approaching limits |
| F3 | Revenue reporting | 2h | MRR, churn, ARPU from Stripe data |

### Track G: Operational Hardening

| # | Feature | Effort | Notes |
|---|---------|--------|-------|
| G1 | 31 account-level ACE-SPECIFIC hardcodes | 4-6h | Phase 4b |
| G2 | Custom domain per tenant | 3-4h | dispatch.acecabs.co.uk |
| G3 | GDPR data export | 2h | Legal requirement before scaling |

### Track H: Product Differentiation

| # | Feature | Notes |
|---|---------|-------|
| H1 | AI route optimisation | Needs booking data from multiple tenants |
| H2 | AI demand prediction | Needs historical volume data |
| H3 | Auto-dispatch | Assign nearest available driver automatically |
| H4 | Driver app rebuild | Modernise with Clerk auth |
| H5 | Public booking widget | Embeddable widget tenants put on their website |
| H6 | Tenant-facing analytics | Bookings/day, revenue, driver utilisation dashboards |

---

## 6. Non-Negotiable Rules

All rules from PRD v1.2 Section 11 carry forward. Additionally:

- No new frontend code uses Redux for server state — use TanStack Query
- No new frontend code uses MUI — use Tailwind + shadcn/ui
- All new frontend pages consume v2 API endpoints only
- All new features must work for any tenant, not just Ace
- Clerk is the only auth provider for new frontend work
- Roles live in the tenant DB, not in Clerk — see shared contract
- No magic role numbers in new code — use `permissions` object or `role` string

---

*This document is a draft. Approve before any implementation begins.*
