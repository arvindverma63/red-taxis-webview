# Driver App Rebuild — Design Spec

**Date:** 2026-08-12 · **Status:** Approved for implementation · **Owner:** Peter (OneSoft UK)
**Companion plan:** `docs/superpowers/plans/2026-08-12-driver-app-rebuild.md`
**Supersedes:** the Flutter app at `src/mobile/driver-app/` (retired after store rollout completes)

---

## 1. Goal

Replace the outsourced Flutter driver app with a **thin native shell + remotely hosted web app**:

- **Shell (Capacitor, iOS + Android):** owns background GPS, push notifications, deep links, secure token storage, offline fallback. Store releases become rare events.
- **Web app (React + Vite, hosted on the Hetzner VPS):** owns 100% of UI. Deployed daily via CI with no reinstall — drivers get the new UI on next open.
- **Backend additions:** journey GPS persistence, a SignalR location hub feeding dispatch/admin maps, and (via the notification-centre workstream) an in-app message feed.

**Non-goals (v1):** customer-facing live tracking UI (channel is designed in, not built), CMAC/provider integrations (adapter seam only), driver→office messaging (drivers reply on their own WhatsApp), en-route/POB status buttons (live GPS replaces them), iPad/tablet layouts.

## 2. Verified current state (what this build stands on)

- The **v1 driver API surface is complete and live**: 29 routes on `RedTaxi.API/Controllers/DriverAppController.cs` plus supporting routes (§10). No v2 driver controller exists or is needed; contracts in §10 are traced from handlers to concrete DTOs.
- **Auth is internal JWT + rotating refresh** via `POST /api/v2/auth/login` / `/refresh` (Clerk removed 2026-06). Tenant is resolved from the username by `TenantResolutionMiddleware` before the handler runs; the token carries tenant context thereafter.
- **Visibility rules already exist server-side** in `BookingService.GetBookings`: per-driver profile flags `ShowAllBookings` (see everything) and `ShowHVSBookings` (additionally see school-contract jobs, with driver colours); default = own jobs only. The scheduler feed is token-scoped — no client-side filtering of other drivers' data.
- **Job offers**: dispatch creates a `JobOffer` row (guid, one active per booking) and pushes FCM `data = { NavId: 1, guid }`. The `RefreshJobOffers` sweep resends up to `Attempts >= 3`, then auto-replies `TimedOut (2002)` and notifies dispatch. Driver replies via `JobOfferReply?jobno=&response=&guid=`.
- **`Arrived` fires the customer "taxi arrived" SMS** (`DriverArrived` → `AtPickup` + notification orchestrator). It must remain a one-tap action.
- **Shift model**: `AppDriverShift { Start=1000, Finish=1001, OnBreak=1002, FinishBreak=1003 }` — maps 1:1 to the GPS engine lifecycle.
- **GPS today** is last-known-position only (`UserProfile/UpdateGPS` overwrite); `PersistGPSLocations` is a commented stub; **no SignalR hubs exist**. Journey trails and realtime fan-out are net-new (§7).
- **Notification centre** (spec `2026-08-12-notification-centre-design.md`) delivers `MobileDevice` registration, `UserNotification` feed (`ListFeed`/`MarkRead`/`MarkAllRead`), and a durable FCM outbox under `/api/v2/notification-centre/*`. **This app consumes that contract** for device registration and the Messages screen; it does not build its own.

## 3. Decisions (ADR summary)

| # | Decision | Rationale |
|---|---|---|
| D1 | **Capacitor** shell, TypeScript | Same language/tooling as monorepo; Codex-friendly; mature plugin ecosystem. Stripping the Flutter app rejected: its GPS is a foreground 10s timer we'd rewrite anyway, in Dart, keeping outsourced baggage. |
| D2 | **Transistor `@transistorsoft/capacitor-background-geolocation`** (paid, ~£320 one-off) | The only hard native problem bought, not built: motion-aware start/stop, battery-tuned, offline queue, iOS/Android parity. **HUMAN GATE: licence purchased at Task 11, not before.** |
| D3 | Web app hosted on the **Hetzner VPS behind Caddy** at `driver.redtaxi.co.uk` (+ `staging-driver.`) | Follows `deploy/staging/` pattern (per-app Dockerfile + Caddy route). Same box as API and SignalR — no third-party proxy in the websocket path. Vercel is being migrated away from. |
| D4 | Scheduler seeds from **`dispatch-v2/src/components/Scheduler/DispatchScheduler.jsx`** | In-monorepo, tested, custom timeline (not FullCalendar), shared `eventVisuals` language with dispatch. Supersedes the earlier external `Adarshsingh7/scheduler` candidate, whose deployed build ships from source we don't hold. |
| D5 | **No Active Job screen / status stepper.** Diary detail sheet carries Navigate · Arrived · Complete · No-show | Approved product decision. En-route/POB signals are dropped; dispatch compensates with the live GPS map. If POB is missed later it's one extra button on the sheet. |
| D6 | Auth tokens **never** in webview URLs | Shell holds refresh token in Keychain/Keystore; web requests tokens over the bridge (§6). Fixes the `?token=` antipattern in the current scheduler webview. |
| D7 | GPS uploads over **batched HTTPS POST**, fan-out over SignalR | Phones post batches (cheap, retryable, offline-friendly); holding a client socket on 4G wastes battery. Consumers (dispatch/admin) subscribe to the hub. |
| D8 | Telemetry to `acetaxislogger.backendcodersindia.com` is **not carried forward** | Shell/web log to our own Serilog ingestion only. |

## 4. Architecture

```text
┌─ Capacitor Shell (iOS/Android) ───────────────────────────────┐
│ splash · permission priming · offline fallback                │
│ Transistor BG-geolocation → batch queue ──────────────┐       │
│ FCM/APNs push → deep-link router                      │       │
│ SecureStorage: refreshToken                           │       │
│ ┌─ WebView: https://driver.redtaxi.co.uk ─────────┐   │       │
│ │ React SPA — all 13 routes (§5)                  │   │       │
│ │ RedTaxiBridge (§6) ⇅ shell                      │   │       │
│ └─────────────────────────────────────────────────┘   │       │
└────────────────────────────────────────────────────────┼──────┘
            │ HTTPS (v1 + v2 APIs)                        │ HTTPS
            ▼                                             ▼
   RedTaxi.API (VPS) ── POST api/DriverApp/PersistGPSLocations
            │                     │ store journey points (jobNo-attributed)
            │                     ▼
            │            SignalR LocationHub ── group tenant:{org} → dispatch-v2 / admin-v2 maps
            │                                └─ group booking:{id} → (future) customer tracking
            ▼
   /api/v2/notification-centre/* ── device registration + Messages feed (dependency)
```

## 5. Web app — routes and screens

Stack: React 18 + Vite + Tailwind (design tokens from `RedTaxi_Design_Language`: dark-first, Inter, status colours; Figma reference to follow — **non-blocking**). App lives at `src/frontend/apps/driver/`. All v1 responses are raw JSON; all v2 responses use the `{ success, data, errors }` envelope — the API client (Task 5) normalises both.

Bottom nav: **Schedule · Messages · Earnings · More**. Offer and job-detail are overlay routes.

| Route | Screen | Data (verified endpoints) | Actions |
|---|---|---|---|
| `/login` | Login + forgot/set password | `POST /api/v2/auth/login` `{username,password}` → `WebLoginResponseDto`; `/forgot-password`, `/set-password` | On success: bridge `setSession`; register device via notification-centre `POST devices` |
| `/` | **Scheduler home** — day timeline seeded from `DispatchScheduler.jsx`; shift bar (Start/Break/Finish + elapsed); `DashTotals` strip | `POST api/DriverApp/DateRange` (`GetBookingsRequestDto {From,To}`) → `GetBookingsResponseDto.Bookings: PersistedBookingModel[]`; `GET DashTotals`; `GET GetOnShiftStatus?userid=`; shift via `GET DriverShift?userid=&status=` | Shift transitions call bridge `setShift` (§6) to arm/pause/disarm GPS |
| `/offer/{guid}` | **Job offer** — full-screen, countdown, spoken announcement (Web Speech API; shell plays notification sound) | `GET RetrieveJobOffer?guid=` → `JobOffer {Guid, Title, Body, Data{bookingId, datetime, asap, pickup, via-i…, drop, passenger, scope, price}, BookingId, BookingDateTime}` | Accept/Reject → `GET JobOfferReply?jobno=&response=&guid=` (`2000/2001`); expiry handled server-side (`2002`) |
| `/job/{id}` | **Detail sheet** (overlay on diary) — passenger, addresses, vias, notes, price | `GET Bookings/FindById?id=` | **Navigate** (bridge `openNavigation`) · **Arrived** `GET Arrived?bookingId=` · **Complete** (sheet → `POST CompleteJob` `{BookingId, WaitingTime, ParkingCharge, DriverPrice, AccountPrice, Tip}`) · **No-show** `GET NoJob?bookingId=`. On Complete/No-show: bridge `setActiveJob(null)` |
| `/availability` | Weekly availability | `GET Availabilities` → `DriverAvailabilitiesDto`; `POST SetAvailability` (`CreateAvailabilityRequestDto {UserId, Date, From, To, GiveOrTake?, Type, Note?}`); `GET DeleteAvailability?id=`; `GET Availability/General` | CRUD |
| `/earnings` | Period totals + per-day breakdown | `GET Earnings?from=&to=` → `EarningsModelTotalsDto[] {Date, CashTotal, AccTotal, RankTotal, CommsTotal, GrossTotal, NetTotal, CashJobsCount…}` | Period picker |
| `/statements` | Statement list + PDF | `GET Statements` → `DriverInvoiceStatementDto[]`; `GET GetStatementHeaders?from=&to=&userId=`; `GET Accounts/DownloadStatement` | View/download PDF |
| `/expenses`, `/expenses/new` | Expense list + add with photo | `GET GetExpenses` (query `GetDriverExpensesRequestDto`); `POST AddExpense` (`DriverExpenseDto {UserId, Date, Category, Description?, Amount}` + image) | Webview `<input capture>` camera |
| `/documents` | Compliance docs status + upload | `POST UploadDocument` (`IFormFile`, `DocumentType {Insurance, MOT, DBS, VehicleBadge, DriverLicence, SafeGuarding, FirstAidCert…}`) | Upload per type |
| `/messages` | Inbound alerts feed (read-only) | Notification-centre `GET /api/v2/notification-centre/feed` + `MarkRead`/`MarkAllRead` (dependency contract) | Deep-link target for NavId 5/6 pushes |
| `/create-booking` | Rank pickup | `GET address/dispatchsearch`, `address/resolve`, `WeBooking/GetAdressSuggestions`; `POST Bookings/GetPrice`; `POST Bookings/RankCreate` | Address → price → create |
| `/profile` | View/edit profile | `GET GetProfile` → `DriverProfileResult {Fullname, Telephone?, Email?, ColorCode?, VehicleReg?, VehicleMake?, VehicleModel?, VehicleColour?, FCM?, LastLogin?}`; `POST UserProfile/Update` | Edit |
| `/settings` | Sound/TTS toggle, GPS diagnostics (bridge `getGpsState`), shell + web versions, logout | local + bridge | Logout → `POST /api/v2/auth/logout`, bridge `clearSession` |

Every screen implements loading / empty / error / offline states; offline banner driven by bridge connectivity events.

## 6. Bridge contract (authoritative — implement exactly)

`src/frontend/apps/driver/src/bridge/types.ts`, mirrored by the shell in `src/mobile/driver-shell/src/bridge.ts`:

```typescript
export interface RedTaxiBridge {
  /** Bridge/schema version, e.g. "1.0.0". Web refuses to run below MIN_SHELL_VERSION. */
  getVersion(): Promise<{ bridge: string; shell: string; platform: 'ios' | 'android' }>;

  // ---- session ----
  /** Called by web after /api/v2/auth/login succeeds. Shell persists refreshToken in secure storage. */
  setSession(s: { userId: number; accessToken: string; tokenExpiryUtc: string; refreshToken: string }): Promise<void>;
  /** Shell returns a valid access token, transparently calling POST /api/v2/auth/refresh when expired. */
  getAccessToken(): Promise<{ accessToken: string } | { error: 'unauthenticated' }>;
  clearSession(): Promise<void>;

  // ---- shift & GPS ----
  /** Web calls on every shift transition. start → BackgroundGeolocation.start(); break → pause uploads,
      keep engine warm; finishBreak → resume; finish → stop + flush queue. */
  setShift(state: 'start' | 'break' | 'finishBreak' | 'finish'): Promise<void>;
  /** Attribution window: non-null while an allocated job is live. Shell stamps jobNo on every
      recorded point until setActiveJob(null) (fired on Complete/No-show). */
  setActiveJob(job: { bookingId: number } | null): Promise<void>;
  getGpsState(): Promise<{ enabled: boolean; tracking: boolean; queuedPoints: number; lastFixUtc?: string }>;

  // ---- navigation & notifications ----
  openNavigation(dest: { lat?: number; lng?: number; address: string; postcode?: string }): Promise<void>;
  /** Web subscribes; shell emits on push tap / cold-start intent. */
  onDeepLink(cb: (link: { route: string }) => void): void;
  playOfferAlert(): Promise<void>; // looping offer ringtone + vibration; stops on route change
  setBadge(count: number): Promise<void>;

  // ---- environment ----
  onConnectivity(cb: (s: { online: boolean }) => void): void;
}
```

**Deep-link routing table (shell):** FCM `data.NavId` → web route: `1 Allocate` → `/offer/{data.guid}` (also `playOfferAlert`) · `2 Unallocate`, `3 Amended`, `4 Cancelled` → `/job/{data.bookingId}` (fallback `/`) · `5 DirectMessage`, `6 GlobalMessage` → `/messages`. Unknown NavId → `/`. Cold start must replay the pending link after webview load.

## 7. Backend additions (file-by-file)

**7.1 GPS ingest & journey storage**
- `src/backend/RedTaxi.Data/Models/GpsPoint.cs` — `Id (long)`, `UserId (int)`, `BookingId (int?)` *(attribution)*, `Latitude (decimal 9,6)`, `Longitude (decimal 9,6)`, `SpeedMps (decimal?)`, `Heading (decimal?)`, `RecordedAtUtc (DateTime)`, `ReceivedAtUtc (DateTime)`. Indexes: `(UserId, RecordedAtUtc)`, `(BookingId)` filtered non-null.
- `src/backend/RedTaxi.Data/RedTaxiDbContext.cs` — add `DbSet<GpsPoint>` + config; migration `<timestamp>_AddGpsPoints.cs`.
- `src/backend/RedTaxi.Application/DTOs/User/Requests/PersistGpsBatchDto.cs` — `record PersistGpsBatchDto(List<GpsBatchPoint> Points)`; `record GpsBatchPoint(decimal Lat, decimal Lng, decimal? SpeedMps, decimal? Heading, DateTime RecordedAtUtc, int? BookingId)`. Max 500 points/batch; reject larger with 400.
- `src/backend/RedTaxi.Application/Features/UserProfile/PersistGpsLocations.cs` — `Command(int UserId, List<GpsBatchPoint> Points) : IRequest<Result>`; bulk insert; then publish latest point to `ILocationBroadcaster`. Also update the user's last-known position (preserving `UpdateGPS` semantics so existing consumers keep working).
- `DriverAppController.cs` — **uncomment/implement** `[Route("PersistGPSLocations")] [HttpPost] [Authorize]`; resolve `UserId` from token (`HttpContext.Items["CurrentUserName"]` → `GetUser.Query`), never from the body.
- Retention: `src/backend/RedTaxi.Application/Features/UserProfile/PurgeGpsPoints.cs` + Hangfire recurring job (daily): delete `BookingId == null` points older than **14 days**; keep job-attributed points **365 days** (both `appsettings` keys: `Gps:UnattributedRetentionDays`, `Gps:JourneyRetentionDays`).

**7.2 Realtime fan-out**
- `src/backend/RedTaxi.API/Hubs/LocationHub.cs` — `[Authorize]`; `OnConnectedAsync` joins `tenant:{TenantOrgId}` (from token); server method `SubscribeBooking(int bookingId)` gated to operator roles (future customer channel uses signed anonymous access — designed, not built).
- `src/backend/RedTaxi.Application/Services/ILocationBroadcaster.cs` + `RedTaxi.Infrastructure/Realtime/SignalRLocationBroadcaster.cs` — `BroadcastAsync(orgId, DriverLocationUpdate { UserId, Lat, Lng, Heading, SpeedMps, RecordedAtUtc, BookingId? })` → group `tenant:{org}` event `"driverLocation"`.
- `Program.cs` — `AddSignalR()`, `MapHub<LocationHub>("/hubs/location")`, DI registration. Caddy must proxy websockets for `/hubs/*` (it does by default).
- dispatch-v2/admin-v2 map consumption is **out of scope here**; a follow-up plan wires `Map.jsx` to `"driverLocation"`.

**7.3 Messages (dependency, not built here)** — Messages screen + device registration consume the notification-centre contract. Office→driver ad-hoc messages become a new event type (`message.direct`) through that pipeline in a follow-up; NavId 5/6 legacy pushes already deep-link correctly meanwhile.

## 8. GPS engine (shell) — configuration of record

Transistor config: `desiredAccuracy: HIGH`, `distanceFilter: 25` (m), `heartbeatInterval: 60` (s, stationary keepalive), `stopTimeout: 5` (min), `foregroundService: true` (Android, persistent notification "On shift — Red Taxi"), `stopOnTerminate: false`, `startOnBoot: false`. Upload policy: buffer points locally; flush every **30 s or 40 points**, whichever first, as one `PersistGPSLocations` batch (gzip request body); exponential backoff offline (queue cap 5,000 points, oldest dropped). Battery target: < 4%/hour urban driving. `break` pauses uploads but keeps queueing at reduced rate (`distanceFilter: 200`); `finish` flushes then stops. Attribution: shell stamps `bookingId` on points while `setActiveJob` is non-null — **the job-time window rule** (allocated + `now >= PickupDate`) is enforced by web calling `setActiveJob` when the diary marks the job live, and clearing it on Complete/No-show.

## 9. Deploy & environments

- Web: `src/frontend/apps/driver/Dockerfile` (nginx-static, mirrors `deploy/staging/admin-v2.Dockerfile`); Caddy snippet: `driver.redtaxi.co.uk` → container, `index.html` `Cache-Control: no-store`, hashed assets `immutable, max-age=31536000`. CI: GitHub Action builds + deploys to VPS on merge to `dev` (staging) / tag (prod).
- Shell: `src/mobile/driver-shell/` Capacitor project; env-switch (staging/prod web URL) via build flavour; `MIN_SHELL_VERSION` handshake — web shows an update screen if the shell is too old.
- Config keys: `VITE_API_BASE_URL`, `VITE_HUB_URL`; **no dev-defaulting** — builds fail without explicit env (fixes the current app's dev-URL default).

## 10. API contract appendix (traced 2026-08-12 from `dev`)

**Envelopes:** v1 `api/DriverApp/*` and other v1 routes return raw JSON. v2 routes return `{ success, data, errors }`.

**Auth:** `POST /api/v2/auth/login {username, password}` → `WebLoginResponseDto { UserId:int, Username, FullName?, Role, RoleId:int, IsAdmin:bool, Token, TokenExpiry:DateTime, RefreshToken }` (401 invalid; 423 locked). `POST /api/v2/auth/refresh {token, refreshToken}` → `WebRefreshResponseDto` (rotated pair). Also: `/forgot-password`, `/set-password`, `/logout`.

**DriverApp (all `[Authorize]`; caller identity from token unless noted):**

| Verb Route | Request | Response |
|---|---|---|
| GET GetProfile | — | `DriverProfileResult` (§5 profile row) |
| GET RetrieveJobOffer | `guid` | `JobOffer` (§5 offer row) or 404 |
| GET GetJobOffers | — | `List<JobOffer>` |
| GET RefreshJobOffers | — | triggers resend/expiry sweep (Attempts ≥ 3 → TimedOut) |
| GET JobOfferReply | `jobno, response (AppJobOffer 2000/2001/2002), guid` | `Result`; deletes offer entry |
| GET NoJob | `bookingId` | `Result`; raises dispatch no-show notification |
| GET GetOnShiftStatus | `userid` | current `AppJobStatus` |
| GET JobStatusReply | `jobno, status (AppJobStatus)` | `Result` *(legacy statuses; new app uses Arrived/Complete only)* |
| GET DashTotals | — | `DriverDashDto { TotalJobCountToday/Week/Month:int, EarningsTotalToday/Week/Month:double, EarningsToday:[…], … }` |
| GET DriverShift | `userid, status (AppDriverShift 1000–1003)` | `Result` |
| POST CompleteJob | `CompleteJobRequestDto { BookingId, WaitingTime:int, ParkingCharge:double, DriverPrice:double, AccountPrice:double, Tip:double }` | `Result` |
| POST UpdateGPS | `UpdateGpsPositionDto { UserId, Longtitude:decimal ⚠ typo is the contract, Latitude, Speed, Heading }` | `Result` *(superseded by batch ingest; kept live)* |
| POST UpdateFCM | `{ fcm:string }` | `Result` *(legacy; new app registers via notification-centre devices)* |
| GET TodaysJobs / FutureJobs | — | `GetBookingsResponseDto` via `GetBookingsByDriver`, Complete/Rejected removed |
| GET CompletedJobs | — | completed bookings list |
| POST DateRange | `GetBookingsRequestDto { From:DateTime, To:DateTime? }` | `GetBookingsResponseDto { Bookings: PersistedBookingModel[], Logout:bool, FocusBookingId:int? }` — **the scheduler feed**; visibility per §2 flags |
| GET Earnings | `from, to` | `List<EarningsModelTotalsDto>` |
| GET Statements / GetStatementHeaders | — / `from,to,userId` | `List<DriverInvoiceStatementDto>` / `List<StatementHeaderResult>` |
| GET Availabilities · POST SetAvailability · GET DeleteAvailability | §5 | §5 |
| GET Arrived | `bookingId` | `Result`; sets `AtPickup` + **sends customer SMS** |
| POST AddExpense · GET GetExpenses | §5 | §5 |
| POST UploadDocument | multipart `file` + `DocumentType` | file reference string |
| POST SetActiveJob `bookingId` · GET GetActiveJob | — | `Result` / `Result<int?>` |

**PersistedBookingModel** (nested in `DTOs/Booking/BookingResponses.cs`; scheduler cell model): `BookingId, Scope (BookingScope: Cash=0 Account=1 Rank=2 …), Status (BookingStatus: None=0 AcceptedJob=1 RejectedJob=2 Complete=3 RejectedJobTimeout=4), CellText, PickupDate, EndDate?, Pickup, DurationMinutes, Destination, Passenger, UserId?, Color?, Cancelled, PhoneNumber?, Email?, Price, AccountNumber?, VehicleType, BookedByName?, PickupPostcode?, DestinationPostcode?` — treat the class as source of truth at implementation.

**Supporting routes:** `GET Bookings/FindById?id=` · `POST Bookings/GetPrice` · `POST Bookings/RankCreate` · `GET address/dispatchsearch` / `address/resolve` / `WeBooking/GetAdressSuggestions` · `GET Availability/General` · `GET Accounts/DownloadStatement` — request/response verified per-screen during Task 9 using `.claude/skills/api-shape-inspector`.

**Enums of record:** `AppDriverShift {1000 Start, 1001 Finish, 1002 OnBreak, 1003 FinishBreak}` · `AppJobOffer {2000 Accept, 2001 Reject, 2002 TimedOut}` · `AppJobStatus {3003 OnRoute … 3009 NoShift}` · `PushNotificationNavId {0 None, 1 Allocate, 2 Unallocate, 3 Amended, 4 Cancelled, 5 DirectMessage, 6 GlobalMessage}` · `DocumentType {Insurance, MOT, DBS, VehicleBadge, DriverLicence, SafeGuarding, FirstAidCert, …}`.

## 11. Human gates (named; the plan halts at each)

1. **G1 — Transistor licence purchase** (opens Task 11). 2. **G2 — Firebase**: reuse the existing project; upload APNs key for iOS push. 3. **G3 — Field GPS test**: real phone, real vehicle, ≥ 2-hour shift incl. signal dead zones; accept on battery < 4%/hr, zero point loss (queue replay verified), correct job attribution. 4. **G4 — Store submissions** (Play + App Store; review notes state native capabilities per D1/D5). 5. **G5 — Driver pilot**: 2–3 Ace drivers, 1 week parallel-run with the Flutter app before fleet cutover.

## 12. Risks

Apple 4.2 (webview-heavy) — mitigated by native GPS/push/offline + polished native surfaces; precedent: hybrid pattern used widely. Webview camera capture on iOS — verify early (Task 9); fallback bridge method reserved. SignalR behind Caddy — websocket proxying is default-on; smoke-tested in Task 12. Legacy Flutter app runs in parallel until G5 passes — both apps hit the same endpoints, which the contract guarantees is safe.
