# Red Taxi — Session Progress Report

**Last updated:** 2026-03-28
**Session:** Full refactor + infrastructure + notifications + testing

---

## Completed ✅

### Phase 0-3: Core Refactor
- [x] Baseline docs (endpoint inventory, class audit)
- [x] .NET 8, health check, Serilog, ProblemDetails
- [x] 7-project split (API, Application, Domain, Data, Infrastructure, Shared, Notifications)
- [x] 232 MediatR handlers across 16 feature areas
- [x] All controllers wired to MediatR (0 direct service calls)
- [x] 7 v2 controllers with envelope responses
- [x] 10 dead handlers identified and removed

### Stabilisation (Tracks 1-5)
- [x] Track 1: Credentials moved to env vars (Google Maps, RabbitMQ, SMTP)
- [x] Track 2: Null reference fixes (GetBooking, FindById, token refresh)
- [x] Track 3: Auth audit documented (15 unsecured endpoints — no v1 changes)
- [x] Track 4: Code quality (sync-over-async, HttpClient, ex.Message leaks, dead code)
- [x] Track 5: ACE-SPECIFIC documented (96 hardcodes, deferred to Phase 4)

### Infrastructure
- [x] Railway API deployment (auto-deploy from main)
- [x] Railway Postgres (48K rows, 1 month data)
- [x] Local Postgres (full 5M rows from MSSQL)
- [x] 4 Vercel frontend apps with CI/CD
- [x] Shell routing at app.redtaxi.co.uk
- [x] CORS configured for all origins (dev + production)
- [x] Environment variables standardised (UPPERCASE)
- [x] Redis removed → in-memory cache
- [x] SQL Server → PostgreSQL migration complete

### Notifications (Novu)
- [x] RedTaxi.Notifications project created
- [x] INotificationOrchestrator with Novu Cloud SDK
- [x] NotificationLog table + EF migration
- [x] Feature flags (legacy/novu/dualwrite per notification type)
- [x] 17 handlers wired with DualWrite (fire-and-forget)
- [x] SMS adapters (TextLocal + Android Gateway)
- [x] v2 Notifications API (list, by-booking, retry, test)
- [x] End-to-end test verified: txn_69c6f417m6rucf6cgrdr
- [x] 44 notification templates audited
- [x] Default mode: legacy (zero risk)

### Testing
- [x] 244 snapshot tests (Verify + WebApplicationFactory)
- [x] 9 write operation + error case tests
- [x] 157 smoke test recordings captured
- [x] Smoke test recorder middleware (opt-in)
- [x] 8 Playwright E2E workflow tests (dispatch app)
- [x] Selector mapping for dispatch booking form
- [x] API capture fixture for E2E tests
- [x] Manual UI testing passed (login, address, bookings)

### Data
- [x] MSSQL → local Postgres: full 5M rows
- [x] MSSQL → Railway Postgres: 48K rows (1 month)
- [x] Identity normalisation fixed (uppercase NormalizedName)
- [x] Unique emails per user
- [x] Password set for Peter (Polopolo121)

---

## Resume Points — What's Next

### Priority 1: E2E Test Execution
- Run 8 Playwright tests against local dispatch + API
- Fix selectors that need adjustment
- Add more workflow variants as needed
- Command: `cd src/tests/e2e && npm run test:headed`

### Priority 2: Snapshot Test Refresh
- Stop VS debugger, run: `cd src/backend && dotnet test --filter SnapshotTests`
- Accept updated .verified.txt files (local full data)
- Re-commit updated snapshots

### Priority 3: Production Frontend Login
- Ensure CORS is deployed on Railway (auto-deploys from push)
- Test login at app.redtaxi.co.uk/admin and app.redtaxi.co.uk/dispatch
- Fix any remaining env var issues

### Priority 4: Novu Workflow Creation
- Another Claude agent is creating 44 workflows in Novu Cloud
- Once done: connect SendGrid provider in Novu dashboard
- Test one real notification end-to-end

### Priority 5: Admin Notifications Page
- React page at /admin/notifications
- Query v2 API: GET /api/v2/notifications
- Filter by channel, status, date
- Click row for detail

### Priority 6: Auth Hardening
- Add [Authorize] to 15 unsecured v2 endpoints
- Do NOT change v1 endpoints (frontend depends on them)

### Priority 7: Phase 4 — Multi-Tenancy
- ITenantContext from JWT
- EF global query filters on TenantId
- TenantConfig table replacing ACE-SPECIFIC hardcodes
- Deferred until UI fully verified

---

## Key Numbers

| Metric | Value |
|--------|-------|
| .NET projects | 8 |
| MediatR handlers | 232 |
| Feature areas | 16 |
| Snapshot tests | 244 |
| E2E tests | 8 |
| Smoke recordings | 157 |
| v1 endpoints | 231 |
| v2 endpoints | 48 |
| Novu handlers wired | 17 |
| Notification templates | 44 |
| Build errors | 0 |

## Dev Workflow

```bash
# Backend (Visual Studio)
Open RedTaxi.sln → F5 → http://localhost:5092

# Frontend dispatch
cd src/frontend/apps/dispatch && npm run dev → http://localhost:5173

# Frontend admin
cd src/frontend/apps/admin && npm run dev → http://localhost:5174

# Run snapshot tests (stop VS first)
cd src/backend && dotnet test --filter SnapshotTests

# Run E2E tests (API + frontend must be running)
cd src/tests/e2e && npm run test:headed

# Production
API: https://red-taxi-production.up.railway.app
Admin: https://red-taxi-admin.vercel.app
Dispatch: https://red-taxi-dispatch.vercel.app
Shell: https://app.redtaxi.co.uk
```
