# Novu Notification System — Build Progress

## Status: PHASE 5 COMPLETE — 244/244 snapshot tests passing
## Started: 2026-03-27 ~18:30 UTC

---

## Phase Checklist

- [x] Phase 1: Novu Cloud setup + env var
- [x] Phase 2: RedTaxi.Notifications project + orchestrator + DB table
- [x] Phase 3: SMS adapter webhook (TextLocal + Android Gateway adapters)
- [x] Phase 4: Feature flags per notification type (NotificationConfig)
- [x] Phase 4b: Workflow consolidation analysis (44 → 15 → 1 workflow, see ADR)
- [x] Phase 4c: Delivery-pipe architecture — Novu handles SMS/WhatsApp/Push only, email stays on SendGrid
- [x] Phase 5: Wire 17 handlers with DualWrite
- [ ] Phase 6: Admin notifications page
- [ ] Phase 7: Testing
- [ ] Phase 8: Commit + push + docs

---

## What's Built

### New Project: `src/backend/RedTaxi.Notifications/`

```
RedTaxi.Notifications/
├── RedTaxi.Notifications.csproj
├── INotificationOrchestrator.cs      ← main interface
├── NovuNotificationOrchestrator.cs   ← Novu Cloud implementation
├── INotificationDbContext.cs         ← marker interface for DbContext
├── INotificationLogStore.cs          ← persistence interface
├── NotificationLogStore.cs           ← EF Core implementation
├── NotificationRequest.cs            ← request DTO
├── NotificationLogEntry.cs           ← DB entity
├── NotificationConfig.cs             ← feature flags
├── NotificationChannel.cs            ← enum
├── NotificationStatus.cs             ← enum
├── NotificationHelper.cs             ← fire-and-forget helper for handlers
├── ServiceRegistration.cs            ← DI setup
└── Adapters/
    ├── ISmsAdapter.cs
    ├── TextLocalSmsAdapter.cs
    └── AndroidGatewaySmsAdapter.cs
```

### New V2 Controller

`RedTaxi.API/Controllers/V2/NotificationsController.cs`
- `GET  /api/v2/notifications` — query log with filters
- `GET  /api/v2/notifications/booking/{id}` — by booking
- `POST /api/v2/notifications/{id}/retry` — retry failed
- `POST /api/v2/notifications/test` — send test notification

### DB Migration

`20260327201922_AddNotificationLog` — creates `NotificationLog` table

### Modified Files

- `RedTaxi.Data/RedTaxiDbContext.cs` — added `DbSet<NotificationLogEntry> NotificationLog`
- `RedTaxi.Data/RedTaxi.Data.csproj` — added Notifications project reference
- `RedTaxi.API/RedTaxi.API.csproj` — added Notifications project reference
- `RedTaxi.API/Program.cs` — registered notification services + INotificationDbContext
- `.env` / `.env.example` — added NOTIFICATION_SYSTEM, NOVU_API_KEY, NOVU_APP_ID

### Handlers Wired (Phase 5)

Pattern: inject `INotificationOrchestrator?` + `NotificationConfig?` (nullable, optional).
Call `NotificationHelper.TrySendAsync()` after existing logic. Never throws.

All handlers trigger the same `send-message` workflow. The Type string is for logging/feature flags only.
The Channels array determines which Novu step fires. Content is pre-rendered by the handler.

| # | Handler | Type String | Channels |
|---|---------|-------------|----------|
| 1 | SendConfirmationText | `booking_confirmation_sms` | Sms |
| 2 | SendCardPaymentReminder | `payment_reminder_sms` | Sms |
| 3 | SubmitTicket | `support_ticket_email` | Email |
| 4 | SendAvailabilityReminder | `availability_reminder_sms` | Sms |
| 5 | CreateAndSendPaymentReceipt | `payment_receipt` | Email |
| 6 | ResendPaymentLink | `payment_link_resent` | Sms |
| 7 | SendPaymentLink | `payment_link_sent` | Sms + Email (dynamic) |
| 8 | SendPaymentReceipt | `payment_receipt_email` | Email |
| 9 | SendQuote | `quote_sent` | Sms + Email (dynamic) |
| 10 | DriverArrived | `driver_arrived_sms` | Sms |
| 11 | AcceptWebBooking | `web_booking_accepted` | Email |
| 12 | CreateCashBooking | `cash_booking_created` | Sms + Push |
| 13 | CreateWebBooking | `web_booking_created` | Push |
| 14 | RejectWebBooking | `web_booking_rejected` | Email |
| 15 | RequestAmendment | `amendment_requested` | Sms |
| 16 | RequestCancellation | `cancellation_requested` | Push |
| 17 | SendWhatsAppMessage | `whatsapp_message` | WhatsApp |

## ENV VARS

```
NOTIFICATION_SYSTEM=legacy          # legacy | novu | dualwrite
NOVU_API_KEY=<from novu.co>        # required for novu/dualwrite mode
NOVU_APP_ID=<from novu.co>         # required for novu/dualwrite mode
NOTIFICATION_OVERRIDES={}           # per-type: {"booking_confirmation_sms":"dualwrite"}
```

## How It Works

```
Handler → existing MessagingService (always runs if mode is legacy/dualwrite)
       → NotificationHelper.TrySendAsync() (runs if mode is novu/dualwrite)
             → NovuNotificationOrchestrator.SendAsync()
                   → logs to NotificationLog (always)
                   → BuildChannelOverrides() disables channels handler didn't request
                   → triggers "send-message" workflow via Novu API
                   → Novu fires ONLY the active channel step(s)
```

### Architecture: Novu as Delivery Pipe

Novu handles **SMS, WhatsApp, and Push** delivery only. All message content is
rendered in the RedTaxi API. One workflow (`send-message`), 1 of 20 slots used.

**Email stays on direct SendGrid** — existing templates, attachment support
(invoices, statements, receipts), and template IDs all work as-is.

| Channel | Delivery | Why |
|---------|----------|-----|
| SMS | Novu (`send-message` → sms step) | Simple body text |
| WhatsApp | Novu (`send-message` → chat step) | Simple body text |
| Push | Novu (`send-message` → push step) | Title + body |
| Email | **Direct SendGrid** (existing MessagingService) | Attachments, existing templates, template IDs |

Handlers pass pre-rendered content:

| Data Key | Used By | Example |
|----------|---------|---------|
| `body` | sms, chat, push | `"Your booking is confirmed on ref: 12345..."` |
| `title` | push only | `"Job Offer"` |

### Channel Override Mechanism

The handler's `Channels` array controls which step fires:

```
Handler sets:  Channels = [WhatsApp]
Orchestrator:  overrides = { "sms": {"active": false}, "push": {"active": false} }
Result:        Only the "chat" (WhatsApp) step fires

Handler sets:  Channels = [Email]
Orchestrator:  skips Novu entirely (email-only → SendGrid handles it)
```

### Novu Workflow (1 of 20 slots used)

| Workflow ID | Steps | Content |
|------------|-------|---------|
| `send-message` | sms + chat + push | `{{body}}`, `{{title}}` |

## Migration Strategy

1. Deploy with `NOTIFICATION_SYSTEM=legacy` → zero change in behavior
2. Sign up for Novu Cloud, set `NOVU_API_KEY`
3. Set `NOTIFICATION_SYSTEM=dualwrite` for one type: `NOTIFICATION_OVERRIDES={"booking_confirmation_sms":"dualwrite"}`
4. Monitor NotificationLog for delivery status
5. If working, expand to more types
6. Once all types verified, switch to `NOTIFICATION_SYSTEM=novu` and remove old calls

## Resume Instructions

If session breaks, tell Claude:
"Continue building the Novu notification system. Read docs/refactor/novu-build-progress.md for current status."
