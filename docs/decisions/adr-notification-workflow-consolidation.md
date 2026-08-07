# ADR: Notification Workflow Consolidation Analysis

> Date: 2026-03-27
> Status: **Implemented** — 1 generic workflow (`send-message`) for SMS/WhatsApp/Push delivery. Email via Resend (SendGrid removed 2026-04-09). No WorkflowMap needed.
> Context: 44 notification types identified in audit, Novu free-plan cap is 20 workflows
> Decision: Novu as delivery pipe only. Templates rendered in RedTaxi API. 1/20 slots used.

---

## 1. Workflow Grouping by Business Event

The 44 notification methods are not 44 independent events. Many are the **same business
event** delivered on **different channels** to **different recipients**. Novu workflows
are designed to be multi-channel — one workflow can contain SMS + Email + Push steps.

| Business Event | Audit Refs | Channels Used | Recipients |
|----------------|-----------|---------------|------------|
| **Booking confirmed** | S1, E9, E10 | SMS, Email | Customer |
| **Booking allocated (driver)** | S2, W1, P1 | SMS, WhatsApp, Push | Driver |
| **Driver arrived** | S3 | SMS | Customer |
| **Booking amended (driver)** | S12, W4, P2 | SMS, WhatsApp, Push | Driver |
| **Booking amended (customer)** | S4 | SMS | Customer (currently no-op) |
| **Booking cancelled (customer)** | S5, E13 | SMS, Email | Customer |
| **Booking cancelled (driver)** | S13, W3, P4 | SMS, WhatsApp, Push | Driver |
| **Booking completed** | S6 | SMS | Customer |
| **Booking rejected** | E11, E12 | Email | Customer |
| **Booking unallocated (driver)** | S14, W2, P3 | SMS, WhatsApp, Push | Driver |
| **Customer quote** | S11, E17 | SMS, Email | Customer |
| **Payment link** | S8, E14 | SMS, Email | Customer |
| **Payment reminder** | S9 | SMS | Customer |
| **Payment receipt** | S10, E15 | SMS, Email | Customer |
| **User registration** | E1, E2 | Email | User/Account |
| **Driver statement** | E3, E4, E5 | Email | Driver |
| **Account invoice** | E6, E7, E8 | Email | Account holder |
| **Account credit note** | E16 | Email | Account holder |
| **Driver availability reminder** | S7 | SMS | Drivers (batch) |
| **Job offer** | P1, P5 | Push | Driver |
| **Job offer timeout** | B4 | Browser Push | Dispatch ops |
| **Web booking request** | B1, B2 | Browser Push | Dispatch ops |
| **Cancellation request** | B3 | Browser Push | Dispatch ops |
| **Support ticket** | E18 | Email (SMTP) | Support desk |
| **Admin alert** | S18, S19 | SMS | Admin (hardcoded) |
| **Ad-hoc SMS** | S15, S16, S17 | SMS | Any |
| **Ad-hoc WhatsApp** | W5, W6 | WhatsApp | Any |
| **Admin push (global)** | P6 | Push | All drivers |
| **Admin push (direct)** | P7 | Push | Specific driver |
| **Browser push test** | B5 | Browser Push | Test only |

**Result: 44 methods → 30 distinct business events.**

---

## 2. Classification of Each Event

### Must remain separate (distinct trigger, distinct template, distinct recipient logic)

| # | Event | Why |
|---|-------|-----|
| 1 | Booking confirmed | Unique customer-facing confirmation with price, ref, addresses |
| 2 | Booking allocated (driver) | Driver-specific with vehicle details, job offer data |
| 3 | Driver arrived | Customer-specific with vehicle details |
| 4 | Booking cancelled (customer) | Customer-facing with date/pickup |
| 5 | Booking cancelled (driver) | Driver-facing, includes COA variant |
| 6 | Booking completed | Review request with tenant-specific URL/phone |
| 7 | Booking rejected | Customer email with rejection reason |
| 8 | Booking unallocated (driver) | Driver-facing with booking details |
| 9 | Customer quote | Unique template with price, return option |
| 10 | Payment link | Customer payment URL |
| 11 | Payment receipt | Customer receipt confirmation |
| 12 | User registration | Credentials email |
| 13 | Driver statement | Statement with financial data + attachment |
| 14 | Account invoice | Invoice with attachment(s) |
| 15 | Job offer | Push with rich data payload (lat/lng, addresses) |

### Can be merged into a generic workflow

| # | Events to merge | Merged workflow | Rationale |
|---|----------------|-----------------|-----------|
| 16 | Booking amended (customer) + Booking amended (driver) | `booking-amended` | Same event, two recipients — one trigger, two subscriber targets |
| 17 | Payment reminder | Merge into `payment-link` | Same template structure, different copy — use payload `isReminder` flag |
| 18 | Account credit note | Merge into `account-invoice` | Same structure: customer + attachment. Use payload `documentType` field |
| 19 | E9+E10 (account/cash booking accepted) | Already same event | Booking confirmed covers both — payload carries `bookingType` |
| 20 | E11+E12 (account/cash booking rejected) | Already same event | One rejection workflow — payload carries `bookingType` |
| 21 | E3+E4+E5 (statement variants) | Already same event | One statement workflow — attachment presence is payload-driven |
| 22 | E6+E7+E8 (invoice variants) | Already same event | One invoice workflow — pro-disability is a payload flag |

### Should be handled as pass-through / not a Novu workflow

| # | Events | Recommendation |
|---|--------|---------------|
| 23 | Ad-hoc SMS (S15, S16, S17) | **One** generic `ad-hoc-sms` workflow OR skip Novu entirely — these are arbitrary message pass-throughs with no template |
| 24 | Ad-hoc WhatsApp (W5, W6) | **One** generic `ad-hoc-whatsapp` OR skip Novu — same reasoning |
| 25 | Admin alert (S18, S19) | **One** `admin-alert-sms` — same template, different trigger context |
| 26 | Admin push global (P6) | **One** `admin-broadcast` — pass-through message |
| 27 | Admin push direct (P7) | Merge with `admin-broadcast` — payload `scope: "direct" | "global"` |
| 28 | Job offer retry (P5) | Merge with Job offer (P1) — same payload, title has `(R{n})` from payload |
| 29 | Browser push (B1-B4) | **One** `dispatch-browser-alert` — title/body from payload, all go to same recipients |
| 30 | Browser push test (B5) | **Drop** — test endpoint, not a production notification |
| 31 | Driver availability reminder (S7) | **One** workflow, but could also be a scheduled job that calls ad-hoc SMS |
| 32 | Support ticket (E18) | **Skip Novu** — this is SMTP to an external ticketing system, not a user notification |

---

## 3. Final Workflow Model

> The analysis above (sections 1-2) explored consolidation from 44 → 15 workflows.
> After further discussion, we went further: **Novu is a delivery pipe only.**
> Templates are rendered in the RedTaxi API. One generic workflow handles all channels.
> Email stays on direct SendGrid (attachments + existing template IDs).

### Novu: 1 workflow (send-message)

| Workflow ID | Steps | Content | Slots Used |
|------------|-------|---------|------------|
| `send-message` | sms + chat + push | `{{body}}`, `{{title}}` | 1 of 20 |

- Handlers pre-render the message body and pass it in `Data["body"]`
- Push also uses `Data["title"]`
- `BuildChannelOverrides()` disables steps the handler didn't request
- Email-only requests skip Novu entirely (logged but not triggered)
- No WorkflowMap needed — all types trigger the same `send-message` workflow

### Channel routing

| Channel | Delivery | Why |
|---------|----------|-----|
| SMS | Novu → sms step | Simple body text |
| WhatsApp | Novu → chat step | Simple body text |
| Push | Novu → push step | Title + body |
| Email | **Direct SendGrid** (existing MessagingService) | Attachments, existing templates + template IDs |
| Support ticket | **Direct SMTP** (existing) | External ticketing system |

### What gets dropped

| Item | Reason |
|------|--------|
| B5 (browser push test) | Test-only, not a notification type |
| E18 (support ticket) | SMTP to external system — not a user notification |

---

## 4. Workflow Count Summary

| Approach | Count | Fits Free Plan? |
|----------|-------|-----------------|
| One workflow per method (original) | 44 | No (limit 20) |
| One workflow per business event | 30 | No |
| Consolidated by payload/recipient | 15 | Yes (5 spare) |
| **Delivery pipe (final decision)** | **1** | **Yes (19 spare)** |

**Final decision: 1 workflow.** Novu is a delivery pipe — templates rendered in code,
email stays on SendGrid. Maximum simplicity, maximum headroom.

---

## 5. If Count Still Too High: Lightweight In-House Module

The codebase **already has** the foundation for this. The existing infrastructure:

```
RedTaxi.Notifications/
├── INotificationOrchestrator.cs          — 4-method interface
├── NovuNotificationOrchestrator.cs       — Triggers Novu API + logs locally
├── NotificationRequest.cs                — Single entry point record
├── NotificationHelper.cs                 — Fire-and-forget wrapper
├── NotificationConfig.cs                 — Feature flags (legacy/novu/dualwrite)
├── NotificationChannel.cs                — Email, Sms, Push, WhatsApp
├── NotificationLogEntry.cs               — Audit trail entity
├── NotificationLogStore.cs               — EF Core log queries
├── Adapters/
│   ├── ISmsAdapter.cs
│   ├── TextLocalSmsAdapter.cs
│   └── AndroidGatewaySmsAdapter.cs
└── ServiceRegistration.cs                — DI wiring
```

To replace Novu, you would:

1. **Replace** `NovuNotificationOrchestrator` with `DirectNotificationOrchestrator`
2. **Add** a `NotificationTemplate` table or in-code template registry:
   ```
   Type → { Channel → { Subject, Body, Variables[] } }
   ```
3. **Add** adapters for each provider (most already exist in `MessageService.cs`):
   - `ISmsAdapter` → TextLocal (done), Twilio
   - `IEmailAdapter` → SendGrid (exists in MessageService)
   - `IPushAdapter` → FCM (exists in PushNotificationService)
   - `IWhatsAppAdapter` → Twilio (exists in MessageService)
4. **Route** channels via `MessagingNotifyConfig` (already exists) + tenant config
5. **Render** templates with simple string interpolation (Handlebars-style `{{var}}` replacement)

**Estimated effort: 2-3 days.** Most provider code already exists and just needs
wrapping into the adapter pattern. The audit trail, feature flags, and handler
integration are already done.

---

## 6. Tradeoff Analysis

### Option A: Keep Novu Cloud (Free Plan) — CHOSEN, then simplified further to 1 workflow

| Dimension | Assessment |
|-----------|-----------|
| **Cost** | Free (up to 30K events/month) |
| **Workflow limit** | Originally 15/20 — **simplified to 1/20 (delivery pipe)** |
| **Multi-tenant** | Novu supports tenant context via subscriber metadata |
| **Template management** | Novu dashboard for editing templates without deploy |
| **Delivery logging** | Novu dashboard + our local NotificationLog table |
| **Migration safety** | Feature flags already support dualwrite — safe to run both |
| **Provider flexibility** | Locked to Novu-supported integrations (SendGrid, Twilio, FCM all supported) |
| **Subscriber preferences** | Free tier includes basic preferences |
| **Risk** | Vendor dependency. Plan limits may tighten. 30K event cap could be hit at scale |
| **Effort to complete** | ~1 day — delete 19 SMS workflows, create 15 consolidated ones |

### Option B: Self-Host Novu (Docker)

| Dimension | Assessment |
|-----------|-----------|
| **Cost** | Server hosting (~£15-30/month for a small VPS) + maintenance |
| **Workflow limit** | Unlimited |
| **Multi-tenant** | Full control |
| **Template management** | Same dashboard, self-hosted |
| **Delivery logging** | Self-hosted Novu dashboard + our local table |
| **Migration safety** | Same feature flag approach works |
| **Provider flexibility** | Full — configure any integration |
| **Risk** | Operational burden: Docker, MongoDB, Redis, upgrades, backups. Novu self-hosted is a complex stack (7+ containers). Overkill for our notification volume |
| **Effort** | ~3-5 days setup + ongoing maintenance |

### Option C: Replace Novu with Internal Notification Service

| Dimension | Assessment |
|-----------|-----------|
| **Cost** | Zero incremental — runs on existing Railway API |
| **Workflow limit** | Unlimited — just code |
| **Multi-tenant** | Full control via TenantConfig table |
| **Template management** | In-code or database templates. No UI editor (but we don't use Novu's editor now either — templates are in code) |
| **Delivery logging** | NotificationLog table already built |
| **Migration safety** | Feature flags already support dualwrite. Swap `NovuNotificationOrchestrator` → `DirectNotificationOrchestrator` |
| **Provider flexibility** | Total — we already have SendGrid, Twilio, TextLocal, FCM code |
| **Subscriber preferences** | Build if needed (low priority — dispatch system, not consumer app) |
| **Risk** | No external dashboard for non-developer notification debugging. More code to maintain |
| **Effort** | ~2-3 days. Adapter pattern already started. Most provider code exists |

### Comparison Matrix

| Factor | A: Novu Cloud (chosen) | B: Self-Host | C: In-House (fallback) |
|--------|:---:|:---:|:---:|
| Monthly cost | Free | £15-30 | £0 |
| Setup effort | Done | 3-5 days | 2-3 days |
| Ongoing maintenance | None | High | Low |
| Workflow slots | **1 of 20** | Unlimited | Unlimited |
| Template management | In code (Novu is delivery only) | In code or Novu | In code |
| Multi-tenant control | Limited | Full | Full |
| Operational complexity | Low | High | Low |
| Vendor lock-in | Low (delivery pipe, easy to swap) | Medium | None |
| Scale headroom | 30K events/mo | Unlimited | Unlimited |
| Migration risk | Low (dualwrite flags) | Medium | Low |

---

## 7. Decision (Implemented)

**GO — Novu Cloud as delivery pipe.** 1 workflow, 1/20 slots, free plan.

What was implemented:
- Single `send-message` workflow with sms + chat + push steps
- Orchestrator uses `BuildChannelOverrides()` to fire only the requested channel(s)
- Email-only requests skip Novu — email stays on direct SendGrid (attachments, template IDs)
- All message content pre-rendered by RedTaxi API handlers
- No WorkflowMap, no per-type workflows, no Novu template management
- 17 handlers wired with dualwrite support via feature flags

**NO-GO for self-hosting Novu** — operational complexity unjustified.

**Option C (In-House) remains the fallback** — the `INotificationOrchestrator` interface
means swapping `NovuNotificationOrchestrator` → `DirectNotificationOrchestrator` requires
zero handler changes. Estimated ~500 lines of new code.

### Fallback Architecture (Option C)

```
Handler
  → NotificationHelper.TrySendAsync()                    [already built]
    → INotificationOrchestrator.SendAsync()               [interface exists]
      → DirectNotificationOrchestrator                    [new: replaces NovuNotificationOrchestrator]
        → TemplateRegistry.Resolve(type, channel)         [new: 15 template groups]
        → TemplateRenderer.Render(template, payload)      [new: simple {{var}} replacement]
        → ChannelRouter.GetChannels(type, tenantConfig)   [new: reads MessagingNotifyConfig]
        → IEmailAdapter.SendAsync()                       [wrap existing SendGrid code]
        → ISmsAdapter.SendAsync()                         [already built: TextLocalSmsAdapter]
        → IPushAdapter.SendAsync()                        [wrap existing FCM code]
        → IWhatsAppAdapter.SendAsync()                    [wrap existing Twilio code]
      → NotificationLogStore.CreateAsync()                [already built]
```

Every component marked `[already built]` exists today. The `[new]` components are:
1. `DirectNotificationOrchestrator` — ~150 lines (same shape as NovuNotificationOrchestrator)
2. `TemplateRegistry` — ~100 lines (static dictionary of type → channel → template)
3. `TemplateRenderer` — ~30 lines (regex `{{var}}` replacement)
4. `ChannelRouter` — ~50 lines (reads MessagingNotifyConfig + tenant overrides)
5. Provider adapters — ~60 lines each (wrap existing MessageService/PushNotificationService methods)

**Total new code: ~500 lines.** No new NuGet dependencies. No new infrastructure.

---

## Next Steps (from here)

1. Connect Novu SMS provider (TextLocal or Twilio) in Novu dashboard
2. Connect Novu Push provider (FCM) in Novu dashboard
3. Enable dualwrite for one SMS notification type in production
4. Monitor NotificationLog for delivery status
5. Expand to more types, then switch from dualwrite to novu-only

---

## Appendix: Full Audit-to-Workflow Mapping

| Audit Ref | Original Method | → Consolidated Workflow | Channel Step |
|-----------|----------------|----------------------|-------------|
| S1 | SendCustomerOnBookedSMS | `booking-confirmed` | sms |
| S2 | SendCustomerOnAllocateSMS | `booking-allocated` | sms |
| S3 | SendCustomerArrivedSMS | `driver-arrived` | sms |
| S4 | SendCustomerOnBookingAmendSMS | `booking-amended` | sms (dormant) |
| S5 | SendCustomerOnBookingCancelledSMS | `booking-cancelled` | sms |
| S6 | SendCustomerOnBookingCompletedSMS | `booking-completed` | sms |
| S7 | SendDriverAvailabilityReminderSMS | `driver-reminder` | sms |
| S8 | SendPaymentLinkSMS | `payment-notification` | sms |
| S9 | SendPaymentLinkReminderSMS | `payment-notification` | sms |
| S10 | SendPaymentReceiptSMS | `payment-notification` | sms |
| S11 | SendCustomerQuoteSMS | `customer-quote` | sms |
| S12 | SendDriverBookingAmendedSMS | `booking-amended` | sms |
| S13 | SendDriverBookingCancelledSMS | `booking-cancelled` | sms |
| S14 | SendDriverBookingUnallocatedSMS | `booking-unallocated` | sms |
| S15 | SendSmsMessage | `ad-hoc-message` | sms |
| S16 | SendSmsAsync | `ad-hoc-message` | sms |
| S17 | SendTextMessage | `ad-hoc-message` | sms |
| S18 | *(inline cash booking alert)* | `ad-hoc-message` | sms |
| S19 | *(inline amendment alert)* | `ad-hoc-message` | sms |
| E1 | SendRegistrationEmail | `user-registration` | email |
| E2 | SendAccountRegistrationEmail | `user-registration` | email |
| E3 | SendDriverStatementEmail | `financial-document` | email |
| E4 | SendDriverStatementEmail (attach) | `financial-document` | email |
| E5 | SendDriverStatementResendEmail | `financial-document` | email |
| E6 | SendAccountInvoiceEmail | `financial-document` | email |
| E7 | SendAccountInvoiceEmailProDisability | `financial-document` | email |
| E8 | SendAccountInvoiceAttachmentsEmail | `financial-document` | email |
| E9 | SendAccountBookingAcceptedEmail | `booking-confirmed` | email |
| E10 | SendCashBookingAcceptedEmail | `booking-confirmed` | email |
| E11 | SendAccountBookingRejectedEmail | `booking-rejected` | email |
| E12 | SendCashBookingRejectedEmail | `booking-rejected` | email |
| E13 | SendAccountBookingCancelledEmail | `booking-cancelled` | email |
| E14 | SendPaymentLinkEmail | `payment-notification` | email |
| E15 | SendPaymentReceiptEmail | `payment-notification` | email |
| E16 | SendAccountCreditNoteEmail | `financial-document` | email |
| E17 | SendCustomerQuoteEmail | `customer-quote` | email |
| E18 | SendEmailRaiseTicket | *(skip Novu — direct SMTP)* | email |
| W1 | SendWhatsAppAllocatedV3 | `booking-allocated` | chat |
| W2 | SendWhatsAppUnAllocated | `booking-unallocated` | chat |
| W3 | SendWhatsAppCancelled | `booking-cancelled` | chat |
| W4 | SendWhatsAppBookingAmended | `booking-amended` | chat |
| W5 | SendWhatsAppMessage | `ad-hoc-message` | chat |
| W6 | SendWhatsApp | `ad-hoc-message` | chat |
| P1 | Push (AllocateBooking) | `booking-allocated` | push |
| P2 | Push (AmendBooking) | `booking-amended` | push |
| P3 | Push (UnallocateBooking) | `booking-unallocated` | push |
| P4 | Push (CancelBooking) | `booking-cancelled` | push |
| P5 | Push (JobOfferTimeout re-send) | `booking-allocated` | push |
| P6 | Push (SendGlobalMessage) | `ad-hoc-message` | push |
| P7 | Push (SendDriverMessage) | `ad-hoc-message` | push |
| B1 | Browser (CreateWebBooking) | `dispatch-alert` | push |
| B2 | Browser (CreateCashBooking) | `dispatch-alert` | push |
| B3 | Browser (RequestCancellation) | `dispatch-alert` | push |
| B4 | Browser (JobOfferTimeout) | `dispatch-alert` | push |
| B5 | Browser (test) | *(drop — test only)* | — |
