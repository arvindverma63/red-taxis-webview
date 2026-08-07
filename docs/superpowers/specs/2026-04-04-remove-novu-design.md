# Remove Novu — Direct Notification Routing

**Date:** 2026-04-04
**Status:** Approved
**Author:** Peter Farrell / Claude

---

## Problem

Novu is an intermediary that adds complexity without benefit:
- SES is sandboxed, so Novu's email routing doesn't work
- SMS goes through Novu's workflow API but Novu doesn't have provider credentials configured
- Result: notifications are "sent" (get transaction IDs) but never actually delivered
- Resend is now configured and verified for email delivery

## Solution

Replace `NovuNotificationOrchestrator` with `DirectNotificationOrchestrator` that
routes directly to providers:
- **Email** → Resend (via `ResendEmailService` already built)
- **SMS** → Webex Interact adapter (already built, API key configured)
- **Push** → Pusher (browser) — already working via separate path
- **WhatsApp** → Twilio (existing adapter in Infrastructure)

Same `INotificationOrchestrator` interface — zero handler changes needed.

## Architecture

Push notifications do NOT go through the orchestrator:
- **Driver mobile push** → Firebase FCM (direct calls in DispatchService/AdminUIService)
- **Browser push (operators)** → Pusher (direct calls in MessagingService.SendBrowserNotification)

The orchestrator only handles Email, SMS, and WhatsApp:

```
Handler → INotificationOrchestrator.SendAsync(request)
                    │
          DirectNotificationOrchestrator
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
    ISmsAdapter  IEmailAdapter  WhatsApp
    (Webex)      (Resend)      (Twilio)
```

## What Changes

### NEW: `RedTaxi.Notifications/DirectNotificationOrchestrator.cs`
Implements `INotificationOrchestrator`. Routes by channel:
- `NotificationChannel.Email` → calls `IEmailAdapter.SendAsync()`
- `NotificationChannel.Sms` → calls `ISmsAdapter.SendAsync()`
- `NotificationChannel.Push` → calls Pusher via existing `SendBrowserNotification`
- `NotificationChannel.WhatsApp` → calls Twilio WhatsApp adapter
- Empty channels (workflow mode) → infer from request data:
  - Has `RecipientEmail`? → send email
  - Has `RecipientPhone`? → send SMS
  - Both? → send both
- Always logs to `NotificationLogStore` (before and after send)
- Returns `NotificationResult` with provider IDs

### NEW: `RedTaxi.Notifications/Adapters/ResendEmailAdapter.cs`
Implements `IEmailAdapter` for operational emails (not SaaS templates).
Uses Resend API for transactional emails (booking confirmations, receipts, etc.)
Simple: subject + HTML body + recipient → Resend API → provider ID.

### MODIFY: `RedTaxi.Notifications/ServiceRegistration.cs`
- Remove: Novu HTTP client registration, NovuApiKey/NovuAppId from config
- Replace: `INotificationOrchestrator` registration from Novu → Direct
- Add: Resend HTTP client, ResendEmailAdapter registration
- Keep: WebexSmsAdapter, SesEmailAdapter (as backup)

### DELETE: `RedTaxi.Notifications/NovuNotificationOrchestrator.cs`

### MODIFY: `RedTaxi.Notifications/NotificationConfig.cs`
- Remove: NovuApiKey, NovuAppId, NovuWorkflowId fields
- Remove: IsNovuEnabled(), GetMode() methods
- Add: `EmailProvider` field ("resend" | "ses")
- Add: `SmsProvider` field ("webex")
- Keep: DefaultMode for legacy compatibility during transition

### MODIFY: `RedTaxi.Notifications/NotificationHelper.cs`
- Remove: IsNovuEnabled() check — always send (direct routing handles it)

## What Does NOT Change

- `INotificationOrchestrator` interface — identical
- All 18 Application handlers — they call `INotificationOrchestrator.SendAsync()` unchanged
- `NotificationLogEntry` / `INotificationLogStore` — same audit trail
- `ISmsAdapter` / `IEmailAdapter` interfaces — same
- `WebexSmsAdapter` — same implementation
- `SesEmailAdapter` — stays as email backup
- `ISaasEmailService` in Platform — separate concern, already using Resend
- `NotificationsController` — same endpoints

## Notification Type → Channel Mapping

| Type | Email | SMS | Push | WhatsApp |
|------|-------|-----|------|----------|
| payment_receipt_email | ✅ | | | |
| payment_link_sent | ✅ | | | |
| quote_sent | ✅ | ✅ | | |
| booking_confirmation_sms | | ✅ | | |
| driver_arrived_sms | | ✅ | | |
| availability_reminder_sms | | ✅ | | |
| payment_reminder_sms | | ✅ | | |
| web_booking_created | ✅ | ✅ | ✅ | |
| web_booking_accepted | ✅ | ✅ | | |
| web_booking_rejected | ✅ | ✅ | | |
| web_booking_amendment | ✅ | ✅ | | |
| web_booking_cancellation | ✅ | ✅ | | |
| whatsapp_message | | | | ✅ |
| support_ticket_email | ✅ | | | |
| test_email | ✅ | | | |
| test_sms | | ✅ | | |

## Environment Variables

| Var | Value | Purpose |
|-----|-------|---------|
| RESEND_API_KEY | (already set) | Resend email API |
| WEBEX_API_KEY | (already set) | Webex Interact SMS API |
| SMS_SENDER | "Ace Taxis" | SMS sender name |
| EMAIL_PROVIDER | "resend" | Default email provider |
| SMS_PROVIDER | "webex" | Default SMS provider |

## Verification

1. Send test email via `/api/v2/notifications/test` → appears in inbox + notification log
2. Send test SMS via `/api/v2/notifications/test` → arrives on phone + notification log
3. Create a web booking → triggers SMS + email notification → both delivered
4. Check notification log page → shows correct channel, status, provider IDs
5. Build passes with 0 errors
6. Existing snapshot tests pass unchanged
