# Notification Migration Plan

Last updated: 2026-04-09

## Architecture Decision: Direct Routing (Implemented)

All channels route directly from the API to the provider. No orchestration layer (Novu removed).

## Current State (LIVE)

| Channel | Provider | Code Path | Status Tracking |
|---------|----------|-----------|----------------|
| Operational email (15 templates) | **Resend** | `MessagingService` → `ResendTemplateEmailService` → Resend API | Webhook → NotificationLog |
| SaaS email (13 templates) | **Resend** | `ResendEmailService` → Resend API | Webhook → NotificationLog |
| Email (backup) | AWS SES | `SesEmailAdapter` (toggle via `EMAIL_PROVIDER=ses`) | SNS → webhook → NotificationLog |
| SMS | Webex Interact | `WebexSmsAdapter` via `DirectNotificationOrchestrator` | Callback → NotificationLog |
| SMS (legacy) | TextLocal | `MessageService.SendSmsAsync` (still in code, rarely used) | None |
| Push (browser) | Pusher | `PusherService` | Client-side only |
| Push (mobile) | Firebase FCM | `PushNotificationService` | None |
| WhatsApp | Twilio | `MessageService` → Twilio API | None |

## Email Migration: SendGrid → Resend (COMPLETE 2026-04-09)

### What was done:
1. **15 operational templates** created in Resend dashboard (editable without code deploy)
2. **`ResendTemplateEmailService`** — fetches template HTML from Resend API, caches in memory, renders variables, sends via `/emails`
3. **`ResendEmailAdapter`** — attachment support (base64 encoded PDF/CSV in Resend payload)
4. **All 16 `MessagingService` email methods** rerouted from SendGrid to Resend
5. **SendGrid fully removed** — NuGet packages, `ISendGridClient`, `AddSendGrid()`, `IEmailSender`, config keys
6. **`MessageService`** stripped to WhatsApp + SMS only (no email methods remain)
7. **Password reset emails** removed (Clerk handles auth notifications)
8. **Test endpoint**: `POST /api/v2/settings/test-email?template=xxx&to=xxx` (Admin role required)

### Templates in Resend:

| # | Template | Attachment | Template ID |
|---|----------|------------|-------------|
| 1 | Registration | — | `88e08815-...` |
| 2 | Account Registration | — | `f622576e-...` |
| 3 | Driver Statement | CSV | `7d381ebd-...` |
| 4 | Driver Statement Resend | CSV | `089e57ab-...` |
| 5 | Account Invoice | PDF | `3c1adc6c-...` |
| 6 | Account Credit Note | PDF | `5d62e03b-...` |
| 7 | Payment Link | — | `6116a16c-...` |
| 8 | Payment Receipt | PDF | `b1b417e3-...` |
| 9 | Booking Accepted (Account) | — | `8e16f9e4-...` |
| 10 | Booking Rejected (Account) | — | `e8a1cb8b-...` |
| 11 | Booking Cancelled (Account) | — | `21053185-...` |
| 12 | Cash Booking Accepted | — | `c65009af-...` |
| 13 | Cash Booking Rejected | — | `184af66f-...` |
| 14 | Quotation | — | `70f99488-...` |
| 15 | Pro Disability Invoice | PDF | `02dfe2d5-...` |

Full template IDs in `ResendTemplateEmailService.Templates` static class.

## What's Built

| Component | File | Status |
|-----------|------|--------|
| `ResendEmailAdapter` | `RedTaxi.Notifications/Adapters/ResendEmailAdapter.cs` | Live — template fetch/cache/render + attachments |
| `ResendTemplateEmailService` | `RedTaxi.Notifications/ResendTemplateEmailService.cs` | Live — 15 operational templates |
| `ResendEmailService` | `RedTaxi.Platform/Email/ResendEmailService.cs` | Live — 13 SaaS templates |
| `SesEmailAdapter` | `RedTaxi.Notifications/Adapters/SesEmailAdapter.cs` | Built — backup provider |
| `WebexSmsAdapter` | `RedTaxi.Notifications/Adapters/WebexSmsAdapter.cs` | Live |
| `DirectNotificationOrchestrator` | `RedTaxi.Notifications/DirectNotificationOrchestrator.cs` | Live |
| NotificationLog | `RedTaxi.Data` + `RedTaxi.Notifications` | Live |
| Webex SMS webhook | `POST /api/v2/delivery-status/sms/webex` | Live |
| SES email webhook | `POST /api/v2/delivery-status/email/ses` | Built |

## Remaining Work

| Item | Effort | Priority |
|------|--------|----------|
| Resend delivery webhook (track opens/bounces/complaints) | 1h | Medium |
| WhatsApp delivery tracking | 1h | Low |
| FCM delivery tracking | 1h | Low |
| Unified notification dashboard in admin-v2 | 2-3h | Medium |
| Remove legacy `SendSmsAsync` from `MessageService` | 15 min | Low |

## Env Vars

```env
# Email (Resend — primary)
RESEND_API_KEY=re_...
RESEND_SENDER_EMAIL=noreply@redtaxi.co.uk
RESEND_SENDER_NAME=Red Taxi

# SMS (Webex)
WEBEX_API_KEY=...
WEBEX_REGION=eu
WEBEX_SENDER=Red Taxi
WEBEX_CALLBACK_URL=https://api.redtaxi.co.uk/api/v2/delivery-status/sms/webex

# Email backup (SES — toggle via EMAIL_PROVIDER=ses)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=eu-west-2
```
