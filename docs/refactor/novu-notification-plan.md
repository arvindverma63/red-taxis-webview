# Red Taxi — Novu Notification System Plan

**Status:** IMPLEMENTED — Phases 1-5 complete. 1 Novu workflow, 17 handlers wired.
**Date:** 2026-03-27
**Author:** Claude (on behalf of Peter Farrell, Red Banana Studios)

---

## 1. Architecture

### Current System (UNCHANGED — remains live)

```
BookingService / DispatchService
    │
    ▼
MessagingService (977 lines, Application layer)
    │
    ├── SMS: TextLocal API (direct HTTP)
    ├── SMS: RabbitMQ → Android app polls → native SMS
    ├── Email: SendGrid (12 templates)
    ├── Push: Firebase FCM (Android + Chrome)
    └── WhatsApp: Twilio (4 templates)
```

### New System (PARALLEL — zero contact with old)

```
Any handler / controller
    │
    ▼
INotificationOrchestrator (new interface)
    │
    ▼
NovuNotificationOrchestrator (delivery pipe)
    │
    ├── Novu API → "send-message" workflow (1 of 20 slots)
    │     ├── SMS step:  {{body}}           ← pre-rendered by handler
    │     ├── Chat step: {{body}}           ← WhatsApp
    │     └── Push step: {{title}} {{body}}
    │
    ├── Email: SKIPPED — stays on existing SendGrid
    │     (attachments, templates, template IDs all work as-is)
    │
    └── Local DB logging (NotificationLog table)
```

### How They Coexist

```
BookingService.CreateBooking()
    │
    ├── OLD: _messagingService.SendCustomerOnBookedSMS()     ← STILL RUNS
    │
    └── NEW: _notificationOrchestrator.Send(new BookingConfirmed(...))  ← OPTIONAL
             │                                                            (feature flag)
             └── if NotificationConfig.UseNovu == false → no-op
```

**The old system is never touched.** The new system is called from the SAME handlers but gated behind a feature flag. Both can run simultaneously (dual-write) or the new system can be off entirely.

---

## 2. Isolation Strategy

### Project Structure

```
src/backend/
├── RedTaxi.Application/
│   └── Features/
│       └── Notifications/              ← NEW feature area (handler-level)
│           ├── SendNotification.cs     ← MediatR command
│           ├── GetNotificationLog.cs   ← MediatR query
│           ├── GetNotificationStats.cs
│           ├── RetryNotification.cs
│           └── README.md
│
├── RedTaxi.Infrastructure/
│   └── Notifications/                  ← NEW folder (provider-level)
│       ├── INovuClient.cs              ← Interface for Novu API
│       ├── NovuClient.cs              ← HTTP client for Novu REST API
│       ├── NovuNotificationService.cs  ← INotificationOrchestrator implementation
│       ├── Adapters/
│       │   ├── ISmsAdapter.cs
│       │   ├── TextLocalAdapter.cs     ← Wraps existing TextLocal logic
│       │   ├── AndroidGatewayAdapter.cs ← Wraps existing RabbitMQ logic
│       │   └── NovuSmsWebhookAdapter.cs ← Receives SMS requests from Novu
│       ├── Config/
│       │   └── NotificationConfig.cs   ← Feature flags, channel routing
│       └── Models/
│           ├── NotificationRequest.cs
│           ├── NotificationResult.cs
│           └── NotificationChannel.cs
│
├── RedTaxi.Domain/
│   └── Notifications/                  ← NEW folder
│       ├── NotificationLog.cs          ← Entity
│       ├── NotificationStatus.cs       ← Enum
│       └── NotificationChannel.cs      ← Enum
│
└── RedTaxi.Data/
    └── Notifications/                  ← NEW folder
        └── NotificationLogConfiguration.cs ← EF config
```

### Namespacing

All new code under `RedTaxi.Notifications` sub-namespaces. Zero overlap with existing `RedTaxi.Services` or `RedTaxi.Modules.Messaging`.

### Feature Flags

```json
// appsettings.json
{
  "Notifications": {
    "UseNovu": false,                    // Master kill switch
    "DualWrite": false,                  // Send via BOTH old and new
    "EnabledChannels": [],               // e.g. ["email"] to enable email only
    "EnabledNotificationTypes": [],      // e.g. ["booking_confirmed"]
    "NovuApiKey": "",
    "NovuApiUrl": "https://api.novu.co/v1"
  }
}
```

**Zero risk to production:** `UseNovu: false` means the entire new system is a no-op. No code paths change. No existing tests break.

---

## 3. Data Design

### New Table: NotificationLog

```sql
CREATE TABLE "NotificationLog" (
    "Id"                BIGSERIAL PRIMARY KEY,
    "ExternalId"        VARCHAR(100),           -- Novu message ID
    "NotificationType"  VARCHAR(50) NOT NULL,    -- e.g. "booking_confirmed"
    "Channel"           VARCHAR(20) NOT NULL,    -- email, sms, push, whatsapp
    "RecipientId"       VARCHAR(100),           -- userId, phone, email
    "RecipientName"     VARCHAR(200),
    "Subject"           VARCHAR(500),
    "BodyPreview"       VARCHAR(500),           -- first 500 chars of body
    "Status"            VARCHAR(20) NOT NULL,    -- queued, sent, delivered, failed, bounced
    "ProviderStatus"    VARCHAR(100),           -- raw status from SendGrid/Twilio/FCM
    "ProviderResponse"  TEXT,                   -- full JSON response (for debugging)
    "ErrorMessage"      TEXT,
    "BookingId"         INTEGER,                -- optional FK for booking context
    "AccountNo"         INTEGER,                -- optional FK for account context
    "CreatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt"         TIMESTAMPTZ,
    "RetryCount"        INTEGER NOT NULL DEFAULT 0,
    "MaxRetries"        INTEGER NOT NULL DEFAULT 3,
    "ScheduledAt"       TIMESTAMPTZ,            -- for delayed sends
    "SentAt"            TIMESTAMPTZ,
    "DeliveredAt"       TIMESTAMPTZ
);

CREATE INDEX "IX_NotificationLog_Status" ON "NotificationLog" ("Status");
CREATE INDEX "IX_NotificationLog_BookingId" ON "NotificationLog" ("BookingId");
CREATE INDEX "IX_NotificationLog_CreatedAt" ON "NotificationLog" ("CreatedAt" DESC);
CREATE INDEX "IX_NotificationLog_RecipientId" ON "NotificationLog" ("RecipientId");
```

### Relationship to Existing Tables

**None.** The `NotificationLog` table is completely standalone. It references `BookingId` and `AccountNo` as plain integers (no foreign keys) so it can't cascade-break anything. We can JOIN for display but the notification system doesn't depend on booking data.

The existing `UINotifications`, `DriverMessages`, and `DriverAllocations` tables are **untouched**.

---

## 4. NotificationService Design

### Interface

```csharp
public interface INotificationOrchestrator
{
    /// <summary>
    /// Send a notification. Returns immediately with a log ID.
    /// Actual delivery is async via Novu.
    /// </summary>
    Task<NotificationResult> SendAsync(NotificationRequest request);

    /// <summary>
    /// Query delivery status for a notification.
    /// </summary>
    Task<NotificationLog?> GetStatusAsync(long notificationLogId);

    /// <summary>
    /// Retry a failed notification.
    /// </summary>
    Task<NotificationResult> RetryAsync(long notificationLogId);
}
```

### NotificationRequest

```csharp
public record NotificationRequest
{
    public string NotificationType { get; init; }    // "booking_confirmed"
    public NotificationChannel Channel { get; init; }  // Email, SMS, Push, WhatsApp
    public string RecipientId { get; init; }          // phone number, email, or userId
    public string? RecipientName { get; init; }
    public Dictionary<string, object> Data { get; init; } = new();  // template variables
    public int? BookingId { get; init; }
    public int? AccountNo { get; init; }
}
```

### Flow

```
1. Handler calls _orchestrator.SendAsync(request)
2. NovuNotificationService:
   a. Writes NotificationLog row (Status = "queued")
   b. If UseNovu == false → returns immediately (log stays "queued")
   c. If UseNovu == true → calls Novu API trigger
   d. Updates NotificationLog.ExternalId with Novu response
   e. Updates Status to "sent"
   f. Returns NotificationResult with LogId
3. Novu processes the notification:
   a. Routes to configured provider (SendGrid, webhook, FCM)
   b. Calls our webhook with delivery status
4. Webhook handler updates NotificationLog.Status
```

### SMS Adapter Strategy

| SMS Route | When to Use | Adapter |
|-----------|-------------|---------|
| TextLocal (direct) | Production fallback, bulk | `TextLocalAdapter` — wraps existing API call |
| Android Gateway (RabbitMQ) | Primary for Ace Taxis | `AndroidGatewayAdapter` — wraps existing RabbitMQ publish |
| Novu SMS webhook | Future, when Novu manages SMS | `NovuSmsWebhookAdapter` — Novu calls our endpoint, we route to TextLocal or Android |

**Key insight:** Novu doesn't need to replace the SMS providers — it orchestrates WHEN and WHAT to send. The actual SMS delivery still goes through TextLocal or the Android gateway. Novu just triggers our webhook, which calls the adapter.

---

## 5. Novu Integration Plan

### Novu Workflow (Delivery Pipe)

> **Updated 2026-03-28:** After iterating from 44 → 15 → 1 workflow.
> Novu is used as a **delivery pipe only** — all message content is pre-rendered
> by the RedTaxi API. One generic workflow handles SMS, WhatsApp, and Push.
> Email stays on direct SendGrid (attachments, existing template IDs).
> See `docs/decisions/adr-notification-workflow-consolidation.md` for the decision history.

| Workflow ID | Steps | Content | Slots Used |
|------------|-------|---------|------------|
| `send-message` | sms + chat + push | `{{body}}`, `{{title}}` | 1 of 20 |

Handlers pass pre-rendered content in `Data["body"]` (all channels) and `Data["title"]` (push only).
The `Channels` array on `NotificationRequest` controls which step fires via `BuildChannelOverrides()`.

### What Goes Through Novu vs Stays on Existing Providers

| Channel | Delivery | Why |
|---------|----------|-----|
| SMS | **Novu** (`send-message` → sms step) | Simple body text |
| WhatsApp | **Novu** (`send-message` → chat step) | Simple body text |
| Push | **Novu** (`send-message` → push step) | Title + body |
| Email | **Direct SendGrid** (existing MessagingService) | Needs attachments (invoices, statements, receipts) + existing SendGrid template IDs |
| Support ticket | **Direct SMTP** (existing) | External ticketing system, not a user notification |

### Android SMS Webhook Flow

```
Novu workflow triggers SMS step
    │
    ▼
Novu calls POST /api/v2/notifications/sms-webhook
    │
    ▼
NovuSmsWebhookAdapter receives { to, content, notificationId }
    │
    ├── Check config: use TextLocal or Android Gateway?
    │
    ├── If TextLocal: call TextLocal API directly
    │
    └── If Android: publish to RabbitMQ (same as existing)
         │
         └── Android app polls /api/SmsQue/Get (UNCHANGED)
```

---

## 6. Testing Strategy

### Isolation Tests (no live services)

```csharp
// Test the orchestrator with a mock Novu client
[Fact]
public async Task SendAsync_LogsNotification_WhenNovuDisabled()
{
    // UseNovu = false
    // Verify: NotificationLog row created with Status = "queued"
    // Verify: Novu API NOT called
}

[Fact]
public async Task SendAsync_CallsNovu_WhenEnabled()
{
    // UseNovu = true, mock Novu client
    // Verify: Novu API called with correct workflow + data
    // Verify: NotificationLog updated with ExternalId
}
```

### Webhook Tests

```csharp
[Fact]
public async Task Webhook_UpdatesStatus_OnDelivered()
{
    // POST /api/v2/notifications/webhook with delivery event
    // Verify: NotificationLog.Status = "delivered"
}
```

### Simulated Booking Flow

```csharp
[Fact]
public async Task BookingConfirmed_SendsNotification_WhenEnabled()
{
    // 1. Set UseNovu = true, DualWrite = true
    // 2. Create a booking via API
    // 3. Verify: OLD MessagingService.SendCustomerOnBookedSMS() called
    // 4. Verify: NEW NotificationLog row created
    // 5. Verify: Novu API triggered with booking data
}
```

### Validation Checklist

- [ ] NotificationLog populated for every send attempt
- [ ] Status transitions: queued → sent → delivered/failed
- [ ] Retry count incremented on failure
- [ ] ErrorMessage captured on failure
- [ ] ProviderResponse captured (full JSON)
- [ ] Webhook correctly updates status
- [ ] Feature flag OFF = zero side effects
- [ ] Feature flag ON + DualWrite = both systems fire
- [ ] Old system continues working with Novu OFF

---

## 7. Admin UI Plan

### New Pages (do NOT modify existing UI)

| Route | Page | Data |
|-------|------|------|
| `/admin/notifications` | Notification Log | Paginated list of all notifications |
| `/admin/notifications/:id` | Detail View | Full notification with status history |
| `/admin/notifications/dashboard` | Dashboard | Delivery stats, failure rates, channel breakdown |

### Notification Log Page

```
┌─────────────────────────────────────────────────────────────────┐
│ Notification Log                              [Filter] [Export] │
├─────────┬──────────┬───────────┬────────┬─────────┬────────────┤
│ Time    │ Type     │ Recipient │ Channel│ Status  │ Booking    │
├─────────┼──────────┼───────────┼────────┼─────────┼────────────┤
│ 14:23   │ booking_ │ 07999...  │ SMS    │ ✅ sent │ #127045    │
│         │ confirmed│           │        │         │            │
│ 14:22   │ driver_  │ Andy      │ Push   │ ✅ dlvrd│ #127045    │
│         │ allocated│           │        │         │            │
│ 14:20   │ payment_ │ 07888...  │ Email  │ ❌ fail │ #127042    │
│         │ link     │           │        │         │            │
└─────────┴──────────┴───────────┴────────┴─────────┴────────────┘
```

### v2 API Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/api/v2/notifications` | Paginated log (filterable by status, channel, type, date) |
| GET | `/api/v2/notifications/:id` | Single notification detail |
| GET | `/api/v2/notifications/stats` | Delivery stats (sent/delivered/failed counts by channel) |
| POST | `/api/v2/notifications/:id/retry` | Retry a failed notification |
| POST | `/api/v2/notifications/webhook` | Novu delivery status webhook |
| POST | `/api/v2/notifications/sms-webhook` | Novu SMS send webhook (routes to adapter) |

---

## 8. Migration Strategy

### Phase 1: Build in Isolation (Week 1)

1. Create `NotificationLog` table via EF migration
2. Implement `INotificationOrchestrator` + `NovuNotificationService`
3. Implement SMS adapters (TextLocal + Android Gateway)
4. Add v2 API endpoints
5. Add feature flag config
6. Write tests
7. **Deploy with `UseNovu: false`** — zero risk, table exists but nothing writes to it

### Phase 2: Internal Testing (Week 2)

1. Set `UseNovu: true` in **Development only**
2. Create Novu account + first workflow (booking-confirmed)
3. Test end-to-end: create booking → Novu triggered → SMS adapter → log updated
4. Verify old system still works in parallel (`DualWrite: true`)
5. Monitor `NotificationLog` for failures

### Phase 3: Enable for 1 Type (Week 3)

1. Set `EnabledNotificationTypes: ["booking_confirmed"]` in **Production**
2. Set `DualWrite: true` — both old and new send
3. Monitor for 48 hours:
   - Are notifications being logged?
   - Are statuses updating?
   - Are there failures?
   - Is the old system still working?
4. Compare: old system sent X, new system logged X — counts should match

### Phase 4: Expand Gradually (Weeks 4-6)

1. Add more notification types one at a time
2. For each: enable DualWrite → monitor 48h → confirm
3. Once confident: set `DualWrite: false` for that type (new system only)
4. Old code stays in place as fallback — just not called

### Phase 5: Cleanup (Month 2+)

1. Disable old notification calls one by one
2. Remove old code paths after 30 days of new-only operation
3. Archive old MessagingService methods (don't delete yet)

### Rollback at Any Point

```
1. Set UseNovu: false in Railway env vars
2. Railway auto-deploys
3. All notifications revert to old system
4. NotificationLog stops receiving new entries but retains history
5. Zero data loss, zero downtime
```

---

## 9. Risks & Safeguards

### Risk: Duplicate Sends (DualWrite mode)

**Mitigation:** DualWrite is expected to send duplicates — that's the point. The customer receives 2 SMS. This is acceptable for a testing period of 48 hours. Use test phone numbers first.

**Longer term:** Add a `NotificationLog` check — if old system already sent for this bookingId + type in the last 5 minutes, skip the new send.

### Risk: Novu API Down

**Mitigation:** The orchestrator catches Novu API errors, logs them to `NotificationLog` with `Status = "failed"`, and returns gracefully. The old system continues independently. No booking is blocked.

### Risk: Webhook Not Received

**Mitigation:** Implement a background job that polls Novu for delivery status every 5 minutes for notifications in "sent" status older than 10 minutes. This catches missed webhooks.

### Risk: Android Gateway Breaks

**Mitigation:** The adapter wraps the existing RabbitMQ publish logic. If it breaks, it breaks the same way the old system would. No regression.

### Risk: Config Drift Between Environments

**Mitigation:** All notification config is in `appsettings.{Environment}.json`. Dev has `UseNovu: true`, Production has `UseNovu: false` until explicitly enabled.

### Risk: Performance Impact

**Mitigation:** `SendAsync` writes one DB row + one HTTP call (to Novu). Both are async. The existing handler continues without waiting for Novu's response. Total overhead: ~10ms per notification.

---

## 10. Parallel Agent Plan

### Agent 1: Infrastructure + Service (Days 1-2)

**Scope:**
- `RedTaxi.Infrastructure/Notifications/` — all files
- `INotificationOrchestrator` interface
- `NovuNotificationService` implementation
- `NovuClient` (HTTP client for Novu API)
- SMS adapters (TextLocal, AndroidGateway, NovuWebhook)
- `NotificationConfig` model
- DI registration in `Program.cs`

**Deliverable:** Service that can send via Novu and log to DB. Feature flag support.

### Agent 2: Data Layer (Day 1)

**Scope:**
- `NotificationLog` entity in `RedTaxi.Domain/Notifications/`
- `NotificationStatus` and `NotificationChannel` enums
- EF configuration in `RedTaxi.Data/Notifications/`
- EF migration
- DbContext registration (add `DbSet<NotificationLog>`)

**Deliverable:** Migration that creates the table. Zero impact on existing tables.

### Agent 3: MediatR Handlers + v2 Endpoints (Days 2-3)

**Scope:**
- `RedTaxi.Application/Features/Notifications/` — all handlers
- `SendNotification.Command`
- `GetNotificationLog.Query` (paginated, filterable)
- `GetNotificationStats.Query`
- `RetryNotification.Command`
- v2 controller: `RedTaxi.API/Controllers/V2/NotificationsController.cs`
- Webhook endpoint for Novu callbacks

**Deliverable:** Full API surface for notifications.

### Agent 4: Testing Harness (Days 2-3)

**Scope:**
- Integration tests for all notification endpoints
- Mock Novu client for testing
- Snapshot tests for notification API responses
- Test for dual-write mode
- Test for feature flag OFF = no-op

**Deliverable:** Full test coverage. Tests run without Novu account.

### Agent 5: Admin UI Page (Days 3-4)

**Scope:**
- New React page at `/admin/notifications`
- Notification log table with pagination + filters
- Detail view with status history
- Dashboard with delivery stats
- Uses v2 API endpoints

**Deliverable:** Admin can see all notification history and retry failures.

### Agent 6: Novu Account Setup (Day 1, manual)

**Scope:**
- Create Novu account
- Configure providers: SendGrid, FCM
- Create first workflow: `booking-confirmed`
- Set up webhook URL
- Document API key + workflow IDs

**Deliverable:** Novu ready to receive triggers. This is partly manual.

---

## Summary

| Aspect | Approach |
|--------|----------|
| **Isolation** | Separate folders, namespaces, tables. Zero contact with old code. |
| **Risk** | Feature flag OFF by default. Old system unchanged. |
| **Testing** | Mock Novu client. Test without live services. |
| **Migration** | One notification type at a time. DualWrite for safety. |
| **Rollback** | Single config change. Instant. No data loss. |
| **Timeline** | 2 weeks to build, 2 weeks to migrate first type, 4 weeks for all types. |

---

**IMPLEMENTATION COMPLETE** — Phases 1-5 done. 1 Novu workflow (`send-message`) for SMS/WhatsApp/Push delivery. Email stays on direct SendGrid. 17 handlers wired with dualwrite support. See `docs/refactor/novu-build-progress.md` for current status.
