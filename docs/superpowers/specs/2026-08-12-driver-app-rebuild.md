# Driver App Rebuild — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter driver app with a Capacitor native shell + remotely hosted React web app (VPS/Caddy), add journey GPS persistence and a SignalR location hub, consuming the existing v1 driver API unchanged and the v2 auth + notification-centre contracts.

**Spec:** `docs/superpowers/specs/2026-08-12-driver-app-rebuild-design.md` (authoritative for every contract, DTO, enum, config value, and route referenced below — read it fully before Task 1).

**Tech Stack:** .NET 8, EF Core 8, PostgreSQL, SignalR, Hangfire, MediatR 12, Serilog, xUnit; React 18, Vite, TypeScript, Tailwind; Capacitor 6, `@transistorsoft/capacitor-background-geolocation`, Firebase Messaging.

## Global Constraints

- Work on an isolated branch; do not commit to `dev` or `main`.
- **Do not modify any existing v1 route, handler, or response shape.** All backend work is additive: new files, plus the two named modifications (uncommenting `PersistGPSLocations`; `Program.cs` registrations).
- Controllers route only; one MediatR handler per use case; return `Result<T>` through the established pattern.
- Resolve caller identity and tenant from the token/`HttpContext` — never from request bodies (exception: the documented legacy `userid` query params, which stay as-is).
- Never log tokens, FCM tokens, GPS coordinates at info level, or PII.
- Web app: no localStorage for tokens (memory + bridge only); every screen ships loading/empty/error/offline states; API base URLs from env with no defaults.
- Human gates G1–G5 (spec §11) halt the plan; do not proceed past a gate without explicit sign-off recorded in the PR.

## File Structure

New: `src/frontend/apps/driver/**` (web app), `src/mobile/driver-shell/**` (Capacitor), backend files per spec §7, `deploy/staging/driver.Dockerfile`, Caddy snippet addition.
Modified: `RedTaxiDbContext.cs`, `DriverAppController.cs` (PersistGPSLocations only), `Program.cs`, CI workflow.

---

## Task 1: GPS entity, migration, batch ingest handler
**Files:** create `RedTaxi.Data/Models/GpsPoint.cs`, `RedTaxi.Application/DTOs/User/Requests/PersistGpsBatchDto.cs`, `RedTaxi.Application/Features/UserProfile/PersistGpsLocations.cs`, migration `_AddGpsPoints`; modify `RedTaxiDbContext.cs`, `DriverAppController.cs`.
- [ ] Implement entity + indexes per spec §7.1; add DbSet; generate migration
- [ ] Implement `PersistGpsLocations.Command` — validate batch ≤ 500, bulk insert, update last-known position, resolve `UserId` from token
- [ ] Uncomment/implement the controller route `[HttpPost] [Authorize] PersistGPSLocations`
- [ ] Tests: `RedTaxi.Tests/UnitTests/PersistGpsLocationsTests.cs` — batch cap, token-derived user, attribution passthrough
- [ ] **Verify:** `dotnet test --filter PersistGps` green; `dotnet ef migrations script` applies clean

## Task 2: SignalR LocationHub + broadcaster
**Files:** create `RedTaxi.API/Hubs/LocationHub.cs`, `RedTaxi.Application/Services/ILocationBroadcaster.cs`, `RedTaxi.Infrastructure/Realtime/SignalRLocationBroadcaster.cs`; modify `Program.cs`.
- [ ] Hub per spec §7.2 (`tenant:{org}` group join from token; `SubscribeBooking` role-gated)
- [ ] Broadcaster publishes `driverLocation` after each ingest batch (latest point only)
- [ ] `Program.cs`: `AddSignalR()`, map `/hubs/location`, DI
- [ ] **Verify:** integration test connects two clients (same/different tenant), asserts isolation; `dotnet test --filter LocationHub` green

## Task 3: Retention job
**Files:** create `RedTaxi.Application/Features/UserProfile/PurgeGpsPoints.cs`; modify Hangfire recurring registration.
- [ ] Purge per spec §7.1 retention keys; config-driven; unit test both windows
- [ ] **Verify:** `dotnet test --filter PurgeGps` green

## Task 4: Web app scaffold
**Files:** create `src/frontend/apps/driver/` (Vite + React + TS + Tailwind), design tokens, router with all 13 routes stubbed, bottom nav shell.
- [ ] Tokens per Design Language (dark-first, Inter, status colours); route stubs render
- [ ] Env: `VITE_API_BASE_URL`, `VITE_HUB_URL` required — build fails if absent
- [ ] **Verify:** `npm run build` succeeds; `npm run dev` renders nav + stubs

## Task 5: API client, auth, bridge stub
**Files:** create `src/driver/src/api/client.ts`, `src/api/v1.ts`, `src/api/v2.ts`, `src/bridge/types.ts`, `src/bridge/webFallback.ts`, `/login` screen.
- [ ] Client normalises raw-v1 vs enveloped-v2 responses; central 401 → refresh-via-bridge → retry-once
- [ ] Bridge interface exactly per spec §6; web fallback (browser dev mode) stores session in memory
- [ ] Login screen + forgot/set-password; on success `setSession` + notification-centre device registration
- [ ] **Verify:** vitest suite for envelope normalisation + refresh flow (mocked); manual login against staging succeeds

## Task 6: Scheduler home
**Files:** create `src/driver/src/screens/Schedule/**` seeded from `dispatch-v2/src/components/Scheduler/DispatchScheduler.jsx` (+ `eventVisuals`, `dateNav`); shift bar; totals strip.
- [ ] Feed = `POST DateRange` day-window; render `PersistedBookingModel` cells (Color, Status, CellText); date paging
- [ ] Shift bar drives `DriverShift` + bridge `setShift`; state recovery via `GetOnShiftStatus`
- [ ] When an allocated booking's `PickupDate` ≤ now and not Complete → call bridge `setActiveJob({bookingId})`
- [ ] **Verify:** component tests for cell mapping + shift transitions; manual against staging shows real diary

## Task 7: Job detail sheet + actions
**Files:** create `src/driver/src/screens/JobSheet/**` (route `/job/{id}` as overlay).
- [ ] `FindById` render; actions Navigate (bridge) · Arrived · Complete (fare sheet → `CompleteJob`) · No-show (`NoJob`); Complete/No-show → `setActiveJob(null)` + diary refresh
- [ ] **Verify:** tests for action wiring incl. `setActiveJob(null)`; manual Arrived triggers customer SMS on staging booking

## Task 8: Job offer screen
**Files:** create `src/driver/src/screens/Offer/**` (route `/offer/{guid}`).
- [ ] `RetrieveJobOffer` render (Data map incl. `via-{i}`), countdown from `BookingDateTime`, Web Speech announce, Accept/Reject → `JobOfferReply`; expired/404 state
- [ ] **Verify:** tests for payload parsing + reply codes 2000/2001; manual offer round-trip from dispatch on staging

## Task 9: Remaining screens
**Files:** create Availability, Earnings, Statements, Expenses (+camera capture), Documents, Messages (notification-centre feed), Rank pickup, Profile, Settings per spec §5.
- [ ] Before each screen: verify its supporting-route shapes with `.claude/skills/api-shape-inspector`; record in PR description
- [ ] iOS-webview camera capture proven for expenses/documents (else reserve bridge fallback and flag)
- [ ] **Verify:** `npm run build` green; per-screen tests; manual pass on staging

## Task 10: Capacitor shell — push, deep links, session
**Files:** create `src/mobile/driver-shell/**` (Capacitor project, iOS+Android), bridge implementation, FCM wiring, deep-link router per spec §6 table, splash/permission-priming/offline surfaces, secure storage, `MIN_SHELL_VERSION` handshake.
- [ ] **Verify:** shell builds both platforms; staged permission flow; push tap (NavId 1/3/5) lands on correct route incl. cold start; token never appears in any URL (assert in webview navigation logs)

## Task 11: GPS engine — **HUMAN GATE G1 (Transistor licence) then G2 (Firebase/APNs)**
**Files:** modify shell — Transistor integration per spec §8 config of record; batch uploader → `PersistGPSLocations`; attribution via `setActiveJob`; break/finish semantics; queue + backoff.
- [ ] **Verify:** simulator route-replay produces correctly batched, attributed points; then **HUMAN GATE G3 field test** per spec §11 acceptance

## Task 12: Deploy + smoke tests
**Files:** create `deploy/staging/driver.Dockerfile`, Caddy snippet (`staging-driver.redtaxi.co.uk`; cache rules per spec §9), CI workflow; smoke tests in `smoke-tests/driver/`.
- [ ] **Verify:** CI deploys on merge; smoke: login → diary loads → hub receives `driverLocation` from a posted batch → offer deep link opens; cache headers asserted (`index.html` no-store)

## Task 13: Store prep + pilot — **HUMAN GATES G4, G5**
- [ ] Store listings, review notes (native capability statement), production Caddy route `driver.redtaxi.co.uk`
- [ ] **Verify:** G4 approvals; G5 one-week parallel pilot sign-off → schedule Flutter retirement
