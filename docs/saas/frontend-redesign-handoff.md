# Red Taxi SaaS Frontend — Redesign Handoff Guide

Last updated: 2026-03-29

## Purpose

This document is for AI tools (Replit, Loveable, Cursor, Claude) that will redesign
the SaaS frontend. It contains everything needed to rebuild the UI without touching
the backend.

## Architecture

```
src/frontend/apps/saas-admin/     ← This Next.js app
├── src/
│   ├── app/[locale]/             ← Pages (App Router)
│   │   ├── (unauth)/page.tsx     ← Landing page (public)
│   │   ├── (auth)/               ← Authenticated pages
│   │   │   ├── dashboard/        ← Dashboard, settings
│   │   │   └── onboarding/       ← Onboarding wizard
│   ├── components/               ← Reusable UI components
│   ├── features/                 ← Feature-specific components
│   │   ├── landing/              ← Landing page sections
│   │   ├── billing/              ← Pricing cards, checkout
│   │   └── dashboard/            ← Dashboard widgets
│   ├── templates/                ← Page layout templates
│   └── utils/AppConfig.ts        ← Plan definitions + Stripe price IDs
```

## Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Auth:** Clerk (handles signup, login, org management)
- **Billing:** Stripe (checkout, portal, subscriptions)
- **Styling:** Tailwind CSS + shadcn/ui components
- **Database:** Drizzle ORM → PostgreSQL (control plane only)
- **Deployment:** Vercel at www.redtaxi.co.uk

## API Endpoints (Backend — DO NOT change)

Base URL: `https://red-taxi-production.up.railway.app` (production)
Base URL: `http://localhost:5092` (development)

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v2/tenant-status` | GET | JWT | Tenant status, usage, banners, access flags |
| `/api/v2/tenants/provision` | POST | JWT (SuperAdmin) | Create new tenant DB |
| `/api/v2/tenants/{orgId}` | GET | JWT | Get tenant details |
| `/api/v2/tenants` | GET | JWT (SuperAdmin) | List all tenants |
| `/api/v2/billing/create-checkout` | POST | JWT | Create Stripe checkout session |
| `/api/v2/billing/portal` | POST | JWT | Create Stripe billing portal session |
| `/api/v2/billing/subscription` | GET | JWT | Get current subscription details |
| `/api/v2/notifications` | GET | JWT | Notification log (paginated) |
| `/api/v2/notifications/test-saas-email` | POST | JWT | Test SaaS email templates |
| `/api/v2/stripe/webhook` | POST | None | Stripe webhook (backend only) |
| `/health` | GET | None | API health check |

## Key API Response Shapes

### Tenant Status (GET /api/v2/tenant-status)
```json
{
  "success": true,
  "data": {
    "status": "active_trial",       // active, active_trial, grace_period, soft_locked, hard_locked
    "planId": "solo",               // solo, team, fleet, enterprise
    "companyName": "Test Taxis",
    "trialDaysLeft": 5,
    "onboardingComplete": false,
    "banner": {
      "type": "trial_warning",      // trial_warning, grace_period, soft_lock, hard_lock, usage_warning
      "message": "Your trial ends in 5 days."
    },
    "usage": {
      "bookingsUsed": 450,
      "bookingsMax": 1500,
      "bookingsPercent": 30.0,
      "smsBalance": 200,
      "warning": null               // "80_percent" | "limit_reached" | null
    },
    "access": {
      "canCreateBookings": true,
      "canEditData": true,
      "canAccessApp": true,
      "isReadOnly": false
    }
  }
}
```

### Subscription (GET /api/v2/billing/subscription)
```json
{
  "success": true,
  "data": {
    "planId": "fleet",
    "status": "active",
    "stripeStatus": "active",
    "currentPriceId": "price_1TG0YP9D0J4wzb0ZYXBxDEF0",
    "trialEndsAt": null,
    "limits": {
      "maxDrivers": 50,
      "maxBookings": 15000,
      "bookingsUsed": 127,
      "smsBalance": 0
    }
  }
}
```

### Provision Tenant (POST /api/v2/tenants/provision)
```json
// Request:
{
  "orgId": "org_clerk_abc123",
  "companyName": "Test Taxis",
  "slug": "test-taxis",
  "phone": "01234 567890",
  "email": "admin@testtaxis.co.uk",
  "postcode": "SW1A 1AA",
  "planId": "solo"
}

// Response:
{
  "success": true,
  "tenant": {
    "orgId": "org_clerk_abc123",
    "companyName": "Test Taxis",
    "databaseName": "redtaxi_test_taxis",
    "planId": "solo",
    "trialEndsAt": "2026-04-05T13:04:16Z",
    "dispatchUrl": "https://app.redtaxi.co.uk/dispatch"
  }
}
```

## Pricing Plans

| Plan | Monthly | Annual (20% off) | Drivers | Bookings/mo |
|------|---------|------------------|---------|-------------|
| Solo | £199 | £159 | 5 | 1,500 |
| Team | £389 | £311 | 20 | 5,000 |
| Fleet | £799 | £639 | 50 | 15,000 |
| Enterprise | Custom | Custom | Unlimited | Unlimited |

Stripe Price IDs in `src/utils/AppConfig.ts`.

## Branding

- **Primary colour:** #DC2626 (red)
- **Logo:** Text "Red Taxi" with 🚕 emoji (no image logo yet)
- **Font:** System font stack (Apple, Segoe UI, Roboto)
- **Tone:** Professional, modern, clean
- **Audience:** UK taxi/minicab operators

## App Links (from dashboard)

- Dispatch: `https://app.redtaxi.co.uk/dispatch`
- Admin: `https://app.redtaxi.co.uk/admin`
- Account Booker: `https://red-taxi-account-booker.vercel.app`

## Pages to Build/Redesign

### 1. Landing Page (/)
- Hero with headline + subheading + CTA button
- Feature grid (4-6 features with icons)
- Pricing section with plan cards + annual toggle
- "Start 7-Day Free Trial" CTA
- Footer with links

### 2. Sign-Up Flow (/sign-up → /onboarding/plan-selection)
- Clerk handles account creation
- After signup, redirect to plan selection
- User picks plan → Stripe checkout with 7-day trial
- After checkout → provision tenant → redirect to onboarding

### 3. Dashboard (/dashboard)
- Company name + plan badge
- Usage cards: bookings (progress bar), drivers (count), SMS balance
- Quick action buttons: "Go to Dispatch", "Go to Admin"
- Trial/lock banner at top (from tenant-status API)
- Recent activity feed (from notifications API)

### 4. Onboarding Wizard (/onboarding)
- Step 1: Company details (name, phone, email, address, postcode)
- Step 2: Add first driver (name, phone, vehicle type)
- Step 3: Settings (base postcode, SMS preferences)
- Step 4: Complete → redirect to dispatch
- Progress indicator, skip button

### 5. Settings (/dashboard/settings)
- Company profile (edit name, phone, address)
- Billing (Stripe portal link)
- Plan & usage (current plan, upgrade button)
- Team members (Clerk org management)

## Environment Variables

```env
NEXT_PUBLIC_API_URL=https://red-taxi-production.up.railway.app
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
DATABASE_URL=postgresql://...  (control plane DB)
```

## Key Constraints

1. All data comes from the API — no direct DB queries from the frontend
2. Clerk handles all auth — don't build custom login forms
3. Stripe handles all billing — don't build payment forms
4. The backend is .NET, not Node — API calls use fetch/axios, not server actions
5. The saas-admin app only manages the platform — it doesn't do taxi dispatch
6. Currency is GBP (£), UK market only for now
