# Red Taxi — Developer Setup Guide

Everything you need to get the full stack running locally after cloning the repo.

---

## Prerequisites

- **Node.js 20+** and npm
- **.NET 8 SDK**
- **PostgreSQL 17** running on `localhost:5432`
- **Git**

---

## 1. Clone and Install

```bash
git clone https://github.com/redbananastudios/red-taxi.git
cd red-taxi
```

Install frontend dependencies for the apps you're working on:

```bash
cd src/frontend/apps/admin-v2 && npm install
cd ../dispatch-v2 && npm install
cd ../account-booker && npm install
cd ../saas-admin && npm install    # only if working on SaaS platform
```

Backend dependencies restore automatically on first `dotnet run`.

---

## 2. Environment Files

Most `.env.development` and `.env.production` files are committed to git. You only need to create **gitignored** files that contain secrets.

### Required: `/.env` (backend API)

Copy the template and fill in values (get secrets from a team lead):

```bash
cp .env.example .env
```

**Minimum for local dev** (the rest can stay empty — integrations just won't fire):

```
DATABASE_URL=Host=localhost;Port=5432;Database=redtaxi;Username=postgres;Password=<your-pg-password>
JWT_SECRET_KEY=<get from team lead — must match across all devs>
JWT_ISSUER=abacusonline.net
JWT_EXPIRY_DAYS=365
JWT_REFRESH_EXPIRY_DAYS=365
SENDGRID_API_KEY=SG.fake
ASPNETCORE_ENVIRONMENT=Development
PUSHER_APP_ID=<get from team lead>
PUSHER_KEY=72a68ffd46f37a9d649a
PUSHER_SECRET=<get from team lead>
PUSHER_CLUSTER=eu
```

### Required: `src/frontend/apps/admin-v2/.env.development`

This file IS tracked in git, but contains a `CLERK_SECRET_KEY` that may need updating. After checkout, verify it has:

```
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_c2ltcGxlLWZlbGluZS0xNS5jbGVyay5hY2NvdW50cy5kZXYk
CLERK_SECRET_KEY=<get from team lead>
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_API_URL=http://localhost:5092
NEXT_PUBLIC_USE_DEV_TOKEN=true
NEXT_PUBLIC_GOOGLE_MAPS_KEY=<get from team lead>
NEXT_PUBLIC_PUSHER_KEY=72a68ffd46f37a9d649a
NEXT_PUBLIC_PUSHER_CLUSTER=eu
NEXT_PUBLIC_TENANT_ORG_ID=org_ace_taxis  # Production: org_3BfMRNcpn9933cL6snGXJ7k1PAN
DISPATCH_ORIGIN=http://localhost:5175    # server-side: admin-v2 rewrites() proxy /dispatch-embed/* here (dispatch is same-origin, no public URL)
```

### Optional: `src/frontend/apps/saas-admin/.env.local` (only if working on SaaS)

```
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=<get from team lead>
CLERK_SECRET_KEY=<get from team lead>
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
DATABASE_URL=<control DB connection string>
NEXT_PUBLIC_API_URL=http://localhost:5092
NEXT_PUBLIC_USE_DEV_TOKEN=true
NEXT_PUBLIC_SUPER_ADMIN_ORG_ID=<get from team lead>
NEXT_PUBLIC_APP_URL=http://localhost:3001
STRIPE_SECRET_KEY=<get from team lead>
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=<get from team lead>
STRIPE_WEBHOOK_SECRET=<get from team lead>
BILLING_PLAN_ENV=dev
```

### Not needed

- `src/frontend/apps/account-booker/.env` — duplicate of tracked `.env.development`
- `src/frontend/apps/dispatch-v2/.env` — duplicate of tracked `.env.development`

(The v1 `admin`, `dispatch`, and `headless-dispatch` apps have been removed from the repo — admin-v2 + dispatch-v2 are the only frontends now.)

---

## 3. Database Setup

You need a local PostgreSQL database named `redtaxi`. Options:

**Option A: Fresh DB with migrations**
```bash
cd src/backend/RedTaxi.API
dotnet ef database update --project ../RedTaxi.Data
```

**Option B: Restore from a dump** (recommended — includes realistic test data)
```bash
pg_restore -h localhost -U postgres -d redtaxi dump.sql
```

Get the dump file from a team lead.

---

## 4. Running the Stack

### Backend API (Terminal 1)

```bash
cd src/backend/RedTaxi.API
dotnet run --urls "http://localhost:5092"
```

Verify: http://localhost:5092/health should return `{"status":"healthy"}`

API docs: http://localhost:5092/scalar/v1

Dev token: http://localhost:5092/dev/token?user=Peter (returns a JWT for local dev)

### Admin v2 (Terminal 2) — port 3000

```bash
cd src/frontend/apps/admin-v2
npm run dev
```

Open http://localhost:3000 — auto-authenticates via dev token (no Clerk login needed locally).

### Dispatch v2 (Terminal 3) — port 5175

```bash
cd src/frontend/apps/dispatch-v2
npm run dev:embed
```

`dev:embed` runs Vite with `--base /dispatch-embed/`. Dispatch is served same-origin
under the admin app, not on its own port/URL: admin-v2's Next.js `rewrites()` proxy
`/dispatch-embed/*` to `DISPATCH_ORIGIN` (set to `http://localhost:5175` in admin-v2
`.env.development`).

- **Embedded:** Open http://localhost:3000/dispatch in admin-v2 — loads `/dispatch-embed`
  in an iframe with auto-auth via postMessage.

### Account Booker (Terminal 4) — port 5175

```bash
cd src/frontend/apps/account-booker
npm start
```

Open http://localhost:5175 — shows "Dev Login" button.

### SaaS Admin (Terminal 5) — port 3001

```bash
cd src/frontend/apps/saas-admin
npm run dev:next
```

Open http://localhost:3001

---

## 5. Authentication

All apps use **Clerk** for authentication in production. For local development, set `USE_DEV_TOKEN=true` (or `NEXT_PUBLIC_USE_DEV_TOKEN=true` for Next.js apps) to bypass Clerk and use the backend's `/dev/token?user=Peter` endpoint instead.

The backend supports **dual auth** — both internal JWT (HS256) and Clerk JWT (RS256) work simultaneously. No backend changes are needed when switching between dev tokens and Clerk.

### Test accounts

- **Dev token user:** Peter (Admin, userId=8) — used automatically in local dev
- **Clerk test instance:** `simple-feline-15.clerk.accounts.dev` (test mode)

---

## 6. Project Structure

```
red-taxi/
├── src/backend/
│   ├── RedTaxi.API/            — Controllers, middleware, DI (start here)
│   ├── RedTaxi.Application/    — 232 MediatR handlers across 16 features
│   ├── RedTaxi.Domain/         — Entities, enums, value objects
│   ├── RedTaxi.Data/           — DbContext, EF Core, migrations
│   ├── RedTaxi.Platform/       — SaaS: tenant lifecycle, billing
│   ├── RedTaxi.Infrastructure/ — External integrations (SMS, payments, maps)
│   ├── RedTaxi.Shared/         — Result<T>, extensions, guards
│   ├── RedTaxi.Notifications/  — Notification orchestrator + audit log
│   └── RedTaxi.Tests/          — 244 snapshot tests (WebApplicationFactory)
├── src/frontend/apps/
│   ├── admin-v2/               — Main admin panel (Next.js + shadcn); embeds dispatch-v2 at /dispatch
│   ├── dispatch-v2/            — Dispatch console (React + Vite); served same-origin under admin at /dispatch-embed
│   ├── account-booker/         — Account booking portal (React + Vite)
│   └── saas-admin/             — SaaS platform (Next.js + Stripe)
├── docs/                       — PRDs, architecture, decisions
└── CLAUDE.md                   — AI assistant instructions
```

---

## 7. Running Tests

```bash
cd src/backend
dotnet test RedTaxi.Tests --filter "FullyQualifiedName~SnapshotTests"
```

244 snapshot tests verify every API endpoint's response shape. If a test fails with a snapshot diff, review the change and accept it if intentional:

```bash
# Accept all snapshot changes
dotnet test RedTaxi.Tests -- --verify accept
```

---

## 8. Branch Workflow

```
feature/xxx  →  PR to dev  (tests must pass)
dev          →  PR to main (tests must pass + manual approval)
main         →  triggers deploy (Railway for API, Vercel for frontends)
```

Never commit directly to `main` or `dev`. Always create a `feature/xxx` branch.

---

## 9. Key Docs

| Doc | Purpose |
|-----|---------|
| `CLAUDE.md` | Master project briefing (read first) |
| `src/frontend/apps/admin-v2/CLAUDE.md` | Admin v2 UI rules and patterns |
| `docs/refactor/prd-v1.2.md` | Full PRD with all phases |
| `docs/prd-v2a-auth-consolidation.md` | Auth migration plan |
| `docs/prd-v2b-admin-rebuild.md` | Admin v2 frontend PRD |
| `docs/prd-v2c-api-completion.md` | v2 API completion status |
| `docs/saas/implementation-status.md` | SaaS feature status |
| `docs/refactor/stabilisation-plan.md` | Tracks 1-5 stabilisation status |

---

## Troubleshooting

**Backend won't start:** Check `DATABASE_URL` in `.env` — Postgres must be running and `redtaxi` database must exist.

**Frontend shows blank page:** Check browser console. If CORS errors, ensure `localhost:3000` (or your port) is in `src/backend/RedTaxi.API/appsettings.Development.json` allowed origins.

**API returns 401:** In dev mode, verify `ASPNETCORE_ENVIRONMENT=Development` is set. The `/dev/token` endpoint only works in Development.

**Clerk login issues in dev:** Don't use Clerk locally — set `USE_DEV_TOKEN=true` in your `.env.development`. Clerk 2FA codes block automated testing.

**Snapshot tests fail after changes:** This is expected if you changed API response shapes. Review the diff and accept if intentional.
