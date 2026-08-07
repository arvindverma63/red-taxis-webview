# TODO: Notification Observability & Push Notifications

**Created:** 2026-04-04
**Priority:** High — needed before production launch
**Depends on:** Resend email pipeline (DONE), Pusher real-time (DONE)

---

## 1. SaaS Platform Notification Dashboard

The SaaS admin at redtaxi.co.uk needs a dashboard showing delivery status
across all channels for platform-level communications.

### What to show:
- **Email delivery rates** — sent, delivered, bounced, complained, opened (from Resend webhooks)
- **SMS delivery rates** — sent, delivered, failed (from Webex/Twilio callbacks)
- **Recent notifications** — filterable log with status, recipient, type, timestamp
- **Failed notifications** — alert banner when delivery failures exceed threshold

### Data source:
- `NotificationLog` table in tenant DB (already populated by all send services)
- Resend webhook events update log entries via `UpdateStatusByProviderIdAsync`
- Webex SMS callbacks do the same

### Where it lives:
- SaaS admin frontend (`src/frontend/apps/saas-admin/`) — new "Notifications" page
- API: `GET /api/v2/notifications` already returns log entries

---

## 2. Per-Tenant Notification Logs

Each tenant operator needs visibility into their notification delivery within
the admin-v2 panel.

### What tenants need:
- **Notification log page** — all emails, SMS, push sent on behalf of their tenant
- **Status per message** — Pending → Sent → Delivered (or Failed/Bounced)
- **Filter by channel** — Email, SMS, Push
- **Filter by type** — booking_confirmed, payment_link, driver_message, etc.
- **Retry failed** — ability to resend failed notifications

### Current state:
- Admin-v2 has `GET /api/v2/notifications` endpoint (returns log entries)
- Admin-v2 has `/notifications` page (currently shows mute preferences only)
- `NotificationLog` table stores all entries per tenant DB
- Backend: `INotificationLogStore` already handles create/update/query

### What's needed:
- Expand the admin-v2 `/notifications` page to show delivery logs
- Add filters (channel, type, status, date range)
- Add retry button for failed entries
- Backend: add `GET /api/v2/notifications/logs` with filtering params

---

## 3. Push Notifications — NOT YET MIGRATED

Push notifications have NOT been changed from the legacy setup.

### Current state:
- **Driver app (mobile):** Uses Firebase Cloud Messaging (FCM) via `NotificationFCM` column
  on UserProfile. FCM tokens registered by the Android app. Push sent via
  `MessageService.cs` in `RedTaxi.Infrastructure`.
- **Browser notifications:** Replaced by Pusher real-time (done in admin-v2).
  Bell icon with popover, audio alerts, per-type mute preferences.
- **Browser FCM (ChromeFCM):** Removed — Pusher replaces it entirely.

### What needs doing:
- [ ] **Evaluate FCM replacement** — FCM still works for the Android driver app.
  Options: keep FCM for mobile, or migrate to Pusher for everything.
  Recommendation: keep FCM for mobile push (proven, reliable for Android),
  Pusher for browser real-time (already done).
- [ ] **Push delivery tracking** — FCM delivery receipts are not currently logged.
  Add FCM delivery status tracking to NotificationLog.
- [ ] **Push notification preferences** — drivers should be able to mute specific
  push notification types (job offers, messages, etc.) from the driver app.
- [ ] **Unify notification orchestration** — currently split between:
  - `DirectNotificationOrchestrator` (operational: Email via Resend, SMS via Webex)
  - `ResendTemplateEmailService` (15 operational email templates via Resend)
  - `ResendEmailService` (SaaS platform emails in RedTaxi.Platform)
  - `MessageService` (WhatsApp via Twilio, legacy SMS via TextLocal)
  - `DirectSesSaasEmailService` (SaaS emails via SES — backup)

  Long-term: consolidate into a single `INotificationService` that routes
  to the right provider per channel (Resend for email, Webex for SMS,
  FCM for mobile push, Pusher for browser real-time).

---

## 4. Notification Channel Summary

| Channel | Provider | SaaS Platform | Tenant Operational | Status Tracking |
|---------|----------|--------------|-------------------|-----------------|
| **Email** | Resend (primary) | ✅ 13 SaaS templates | ✅ 15 operational templates (SendGrid removed 2026-04-09) | ✅ Webhook → NotificationLog |
| **Email** | AWS SES (backup) | ✅ Available via config | ✅ Available via `EMAIL_PROVIDER=ses` | ✅ SNS → NotificationLog |
| **SMS** | Webex Interact | ❌ N/A | ✅ Booking alerts | ✅ Callback → NotificationLog |
| **SMS** | Twilio | ❌ N/A | ✅ WhatsApp | ❌ No status tracking |
| **Push (mobile)** | Firebase FCM | ❌ N/A | ✅ Driver app | ❌ No status tracking |
| **Push (browser)** | Pusher | ✅ Bell icon alerts | ✅ Bell icon alerts | ❌ Client-side only |

### Operational email migration: COMPLETE (2026-04-09)
SendGrid fully removed. All 15 operational templates now via Resend (`ResendTemplateEmailService`).
- Templates editable in Resend dashboard (no code deploy needed)
- 6 templates support attachments (PDF/CSV)
- Future: per-tenant Resend API keys or shared key with tenant tags

---

## 5. Priority Order

1. **Tenant notification log page** in admin-v2 (HIGH — operators need visibility)
2. **SaaS notification dashboard** in saas-admin (MEDIUM — platform monitoring)
3. **FCM delivery tracking** (MEDIUM — understand mobile push health)
4. ~~**Tenant operational email migration** to Resend~~ — **DONE** (2026-04-09)
5. **Unified notification orchestration** (LOW — architectural cleanup)
