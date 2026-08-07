# Notification Templates Audit

> Generated: 2026-03-27
> Scope: `src/backend/` — all SMS, Email, Push, and WhatsApp notification templates
> Status: **Read-only audit — no code was modified**

---

## Table of Contents

1. [SMS Notifications](#1-sms-notifications)
2. [Email Notifications](#2-email-notifications)
3. [WhatsApp Notifications](#3-whatsapp-notifications)
4. [Push Notifications (Android FCM)](#4-push-notifications-android-fcm)
5. [Browser Push Notifications (Chrome FCM)](#5-browser-push-notifications-chrome-fcm)
6. [Messaging Configuration](#6-messaging-configuration)
7. [Summary Statistics](#7-summary-statistics)

---

## 1. SMS Notifications

All SMS is sent via two paths:
- **TextLocal API** (`SendSmsAsync`) — direct HTTP API call
- **RabbitMQ queue** (`SendToRabbitMq`) — queued for local Android SMS gateway to send

A `"\r\n\r\n(Please do not reply.)"` suffix is appended to RabbitMQ messages under 138 chars.

| # | Method | File | Recipient | Trigger | Template | Variables | ACE-SPECIFIC? |
|---|--------|------|-----------|---------|----------|-----------|---------------|
| S1 | `SendCustomerOnBookedSMS` | MessagingService.cs:552 | Customer | Booking created | `Booking from {PickupPostCode} to {DestinationPostCode} for {PickupDateTime} is confirmed on ref: {jobno}, the cost of your journey is £{Price}.\r\n\r\nThank you for booking with Ace Taxis.` | tel, jobno (looks up PickupDateTime, PickupPostCode, DestinationPostCode, Price) | **YES** — "Ace Taxis" |
| S2 | `SendCustomerOnAllocateSMS` | MessagingService.cs:564 | Customer | Booking allocated to driver | `You booking with Ace Taxis has been allocated, your drivers name is {name} in a {color} {make} {model} registration no {reg}.\r\n\r\nAce Taxis.` | tel, make, model, color, reg, drivername | **YES** — "Ace Taxis" (x2). Note: method body does NOT actually send (SendToRabbitMq call is commented out) |
| S3 | `SendCustomerArrivedSMS` | MessagingService.cs:587 | Customer | Driver arrived | `Your Ace Taxi has arrived.\r\n\r\n Your drivers name is {name} in a {color} {make} {model} registration no {reg}.\r\n\r\nAce Taxis.` | tel, destination, make, model, color, reg, drivername | **YES** — "Ace Taxi" and "Ace Taxis" |
| S4 | `SendCustomerOnBookingAmendSMS` | MessagingService.cs:611 | Customer | Booking amended | *(Empty — method body is `// ignore`)* | tel | N/A (no-op) |
| S5 | `SendCustomerOnBookingCancelledSMS` | MessagingService.cs:617 | Customer | Booking cancelled | `Your booking for {date} from {pickup} has been cancelled.\r\n\r\nThank you for using Ace Taxis.` | tel, date, pickup | **YES** — "Ace Taxis". Note: SendToRabbitMq call is commented out (not sending) |
| S6 | `SendCustomerOnBookingCompletedSMS` | MessagingService.cs:625 | Customer | Booking completed (one-time review request) | `Thank you for using Ace Taxis, 01747 821111.\r\n\r\nIf you have a moment we would really appreciate if you would leave us a review. https://cutt.ly/NefYovLC` | tel | **YES** — "Ace Taxis", phone "01747 821111", review URL hardcoded |
| S7 | `SendDriverAvailabilityReminderSMS` | MessagingService.cs:644 | Driver (all active) | Scheduled reminder | `REMINDER!!\r\n\r\nHi {FullName},\r\n\r\nIf you haven't already, please can you make sure you add your availability for the coming week.\r\n\r\nThank you.\r\n\r\nAce Taxis` | FullName, PhoneNumber (per driver) | **YES** — "Ace Taxis", also filters `NonAce == false` |
| S8 | `SendPaymentLinkSMS` | MessagingService.cs:664 | Customer | Payment link sent | `Thank you for booking with Ace Taxis, please use the link below to make payment for your journey.\r\n\r\n{link}` | telephone, link | **YES** — "Ace Taxis" |
| S9 | `SendPaymentLinkReminderSMS` | MessagingService.cs:674 | Customer | Payment reminder | `Hi,\r\n\r\nThis is a reminder from Ace Taxis that payment for your journey is due ASAP, please use the link below to make payment.\r\n\r\n{link}` | telephone, link | **YES** — "Ace Taxis" |
| S10 | `SendPaymentReceiptSMS` | MessagingService.cs:684 | Customer | Payment received | `Thank you for your recent payment to Ace Taxis. The link to your receipt is below.\r\n\r\n{link}` | telephone, link | **YES** — "Ace Taxis" |
| S11 | `SendCustomerQuoteSMS` | MessagingService.cs:533 | Customer | Quote requested | (with return): `Dear {Passenger},\r\n\r\nYour quote for {Pickup} to {Destination} with {Passengers} passengers is £{Price}.The price for your return journey on {ReturnTime} will be £{ReturnPrice}\r\n\r\nAce Taxis.` / (without return): `Dear {Passenger},\r\n\r\nYour quote for {Pickup} to {Destination} with {Passengers} passengers is {Price}.\r\n\r\nAce Taxis.` | Passenger, Pickup, Destination, Passengers, Price, ReturnTime, ReturnPrice, Phone | **YES** — "Ace Taxis" |
| S12 | `SendDriverBookingAmendedSMS` | MessagingService.cs:816 | Driver | Booking amended | `Your booking on {date} for {passenger} has been amended.` | tel, date, passenger, nonace flag | No |
| S13 | `SendDriverBookingCancelledSMS` | MessagingService.cs:833 | Driver | Booking cancelled | (COA): `Your booking on {date} for {passenger} has been marked as a COA.` / (Cancel): `Your booking on {date} for passenger {passenger} has been cancelled.` | tel, date, passenger, coa flag, nonace flag | No |
| S14 | `SendDriverBookingUnallocatedSMS` | MessagingService.cs:851 | Driver | Booking unallocated | `Your booking on {date} for passenger {passenger} has been unallocated.` | tel, date, passenger | No |
| S15 | `SendSmsMessage` | MessagingService.cs:693 | Any | Ad-hoc SMS send | *(pass-through — sends arbitrary message via RabbitMQ)* | telephone, message | No |
| S16 | `SendSmsAsync` (base) | MessageService.cs:36 | Any | Ad-hoc SMS via TextLocal API | *(pass-through — sends arbitrary message via TextLocal HTTP API)* | message, number | No |
| S17 | `SendTextMessage` (handler) | Features/Messaging/SendTextMessage.cs | Any | Admin sends text via API | *(pass-through — calls SendSmsAsync with arbitrary message)* | Telephone, Message, Username | No |
| S18 | *(inline)* | Features/WebBookings/CreateCashBooking.cs:90-91 | Admin (hardcoded numbers) | Cash booking created via website | `You have received a new cash booking on ace taxis website, take a look ;-)` | Sent to 07870545494 and 07572382366 | **YES** — "ace taxis", hardcoded phone numbers |
| S19 | *(inline)* | Features/WebBookings/RequestAmendment.cs:52 | Admin (hardcoded number) | Account customer requests amendment | `You have received a amendment request from an account customer, take a look ;-)` | Sent to 07870545494 | **YES** — hardcoded phone number |

### SMS Delivery Notes

- **RabbitMQ path** (SendToRabbitMq): Messages are queued to a RabbitMQ exchange, then consumed by an Android phone app (`Module/local-sms/`) that sends via the phone's native SMS. Hardcoded exclusions: phone numbers `07825350912` and `07738825598` are silently dropped.
- **TextLocal path** (SendSmsAsync): Direct HTTP POST to `api.txtlocal.com/send/` with configured API key and sender name.
- **NonAce drivers**: Some methods (S12, S13) have a `nonace` flag — NonAce drivers get TextLocal/Twilio SMS instead of RabbitMQ.

---

## 2. Email Notifications

> **MIGRATED 2026-04-09:** All operational emails migrated from SendGrid to **Resend**. Templates are hosted in the Resend dashboard (editable without code deploy). The codebase fetches template HTML from the Resend API, caches it, renders variables server-side, and sends via `/emails`. SendGrid NuGet packages and all SendGrid code have been fully removed.
>
> Service: `ResendTemplateEmailService` in `RedTaxi.Notifications/ResendTemplateEmailService.cs`
> Template IDs: `ResendTemplateEmailService.Templates` static class

The table below documents the original SendGrid template IDs for historical reference. Current Resend template IDs are in `ResendTemplateEmailService.Templates`.

| # | Method | File | Recipient | Trigger | SendGrid Template ID | Subject Line | Variables (DTO) | ACE-SPECIFIC? |
|---|--------|------|-----------|---------|---------------------|--------------|-----------------|---------------|
| E1 | `SendRegistrationEmail` | MessagingService.cs:188 | Driver/User | User registered | `d-588cd7318d7e40e4b4246e0fca058d59` | `Ace Taxis - User Registration.` | userid, accno, fullname, reg, username, password | **YES** — subject |
| E2 | `SendAccountRegistrationEmail` | MessagingService.cs:180 | Account User | Account user registered | `d-6378c357f86244f696a4d63db4239c4c` | `Ace Taxis - Account User Registration.` | userid, accno, fullname, reg, username, password | **YES** — subject |
| E3 | `SendDriverStatementEmail` | MessagingService.cs:196 | Driver | Statement generated | `d-d2a3ffefe29940369e7426df64169845` | `Ace Taxis Driver Statement.` | userid, fullname, reg, statementid, period, transactions[], commstotal, nettotal | **YES** — subject |
| E4 | `SendDriverStatementEmail` (with attachment) | MessagingService.cs:204 | Driver | Statement generated (PDF) | `d-d2a3ffefe29940369e7426df64169845` | `Ace Taxis Driver Statement.` | Same as E3 + filename, base64Content attachment | **YES** — subject |
| E5 | `SendDriverStatementResendEmail` | MessagingService.cs:213 | Driver | Statement resent | `d-877358eb4ca54c62bd24432ce55f6d4b` | `Ace Taxis Driver Statement.` | filename, base64Content attachment | **YES** — subject |
| E6 | `SendAccountInvoiceEmail` | MessagingService.cs:222 | Account holder | Invoice generated | `d-7971cadd2ddd4532aa0f8192cfbe26a7` | `Ace Taxis Invoice` | customer, invno + filename, base64Content attachment | **YES** — subject |
| E7 | `SendAccountInvoiceEmailProDisability` | MessagingService.cs:255 | Account holder | Pro-disability invoice | `d-81e7ebe0e76241448e37b5b3cf0ac8e4` | `Ace Taxis Invoice - {passengerName}` | customer, invno + filename, base64Content | **YES** — subject, hardcoded template ID |
| E8 | `SendAccountInvoiceAttachmentsEmail` | MessagingService.cs:285 | Account holder | Invoice with multiple attachments | `d-7971cadd2ddd4532aa0f8192cfbe26a7` | `Ace Taxis - Invoice` | customer + dictionary of attachments | **YES** — subject |
| E9 | `SendAccountBookingAcceptedEmail` | MessagingService.cs:156 | Account holder | Account booking accepted | `d-b1c28ecd630b4d3dab7866d8137fc946` | `Ace Taxis - Booking Accepted` | accno, passengername, pickupaddress, destinationaddress, datetime, bookingId, price | **YES** — subject |
| E10 | `SendCashBookingAcceptedEmail` | MessagingService.cs:140 | Customer (cash) | Cash booking accepted | `d-e50cef9cdd5347d79eda80c8de33188d` | `Ace Taxis - Booking Accepted` | accno, passengername, pickupaddress, destinationaddress, datetime, bookingId, price | **YES** — subject |
| E11 | `SendAccountBookingRejectedEmail` | MessagingService.cs:172 | Account holder | Account booking rejected | `d-267592ce42de41e2909b2ad667cdbddd` | `Ace Taxis - Booking Rejected` | accno, passengername, pickupaddress, destinationaddress, reason, datetime | **YES** — subject |
| E12 | `SendCashBookingRejectedEmail` | MessagingService.cs:164 | Customer (cash) | Cash booking rejected | `d-0b8454822a1e4571bb925126f5e7683e` | `Ace Taxis - Booking Rejected` | accno, passengername, pickupaddress, destinationaddress, reason, datetime | **YES** — subject |
| E13 | `SendAccountBookingCancelledEmail` | MessagingService.cs:148 | Account holder | Account booking cancelled | `d-312f2ba92b364f84addffcffbe247724` | `Ace Taxis - Booking Cancelled` | accno, passengername, pickupaddress, destinationaddress | **YES** — subject |
| E14 | `SendPaymentLinkEmail` | MessagingService.cs:266 | Customer | Payment link sent | `d-743a839078a34921929932a5a73ef49a` | `Ace Taxis Payment Link` | customer, link | **YES** — subject |
| E15 | `SendPaymentReceiptEmail` | MessagingService.cs:274 | Customer | Payment received | `d-46dd090bd0a44088ab2b490728ce7b00` | `Ace Taxis - Payment Receipt` | customer + filename, base64Content attachment | **YES** — subject |
| E16 | `SendAccountCreditNoteEmail` | MessagingService.cs:246 | Account holder | Credit note issued | `d-2dbd0524f3ed475c8d28a190ec0d1fa4` | `Ace Taxis Credit Note` | customer, creditnoteId + filename, base64Content | **YES** — subject |
| E17 | `SendCustomerQuoteEmail` | MessagingService.cs:231 | Customer | Quote requested | `d-17d734a8a9054d51981ead3eaf904fc0` | `Ace Taxis Quotation` | price, datetime, passengername, pickupaddress, destinationaddress | **YES** — subject |
| E18 | `SendEmailRaiseTicket` | MessagingService.cs:95 | Support desk | Support ticket raised | *(Plain text SMTP, not SendGrid)* | *(caller-provided subject)* | subject, messageBody, stream attachment | **YES** — hardcoded recipient `support@acetaxis.raiseaticket.com`, uses SMTP not SendGrid |

### SendGrid Template ID Reference (HISTORICAL — SendGrid removed 2026-04-09)

| Template Enum | Old SendGrid ID | New Resend Template |
|---------------|-----------------|---------------------|
| Register | `d-588cd7318d7e40e4b4246e0fca058d59` | `Templates.Registration` |
| DriverStatement | `d-d2a3ffefe29940369e7426df64169845` | `Templates.DriverStatement` |
| AccountInvoice | `d-7971cadd2ddd4532aa0f8192cfbe26a7` | `Templates.AccountInvoice` |
| PaymentLink | `d-743a839078a34921929932a5a73ef49a` | `Templates.PaymentLink` |
| PaymentReceipt | `d-46dd090bd0a44088ab2b490728ce7b00` | `Templates.PaymentReceipt` |
| AccountRegistration | `d-6378c357f86244f696a4d63db4239c4c` | `Templates.AccountRegistration` |
| AccountBookingAccepted | `d-b1c28ecd630b4d3dab7866d8137fc946` | `Templates.BookingAcceptedAccount` |
| AccountBookingRejected | `d-267592ce42de41e2909b2ad667cdbddd` | `Templates.BookingRejectedAccount` |
| AccountBookingCancelled | `d-312f2ba92b364f84addffcffbe247724` | `Templates.BookingCancelledAccount` |
| DriverStatementResend | `d-877358eb4ca54c62bd24432ce55f6d4b` | `Templates.DriverStatementResend` |
| AccountCreditNote | `d-2dbd0524f3ed475c8d28a190ec0d1fa4` | `Templates.AccountCreditNote` |
| Quotation | `d-17d734a8a9054d51981ead3eaf904fc0` | `Templates.Quotation` |
| CashBookingAccepted | `d-e50cef9cdd5347d79eda80c8de33188d` | `Templates.CashBookingAccepted` |
| CashBookingRejected | `d-0b8454822a1e4571bb925126f5e7683e` | `Templates.CashBookingRejected` |
| *(Pro-Disability Invoice)* | `d-81e7ebe0e76241448e37b5b3cf0ac8e4` | `Templates.ProDisabilityInvoice` |

> **Note:** Templates are now in Resend dashboard (editable without code deploy). The codebase fetches template HTML from Resend API, caches it in memory, renders `{{{variable}}}` placeholders server-side, and sends via the Resend `/emails` endpoint. Subject lines are rendered from the template's subject field, with `{{{company_name}}}` replacing the old hardcoded "Ace Taxis".

---

## 3. WhatsApp Notifications

All WhatsApp messages sent via **Twilio** using pre-approved content templates (Content SIDs). The `from` number is hardcoded as `whatsapp:+441747822228`. Messages use Twilio's `contentSid` + `contentVariables` pattern.

| # | Method | File | Recipient | Trigger | Twilio Content SID | Variables | ACE-SPECIFIC? |
|---|--------|------|-----------|---------|-------------------|-----------|---------------|
| W1 | `SendWhatsAppAllocatedV3` | MessagingService.cs:384 | Driver | Booking allocated | `HX6806e9e02c16fa365de2f175a66233d8` | 1=date, 2=passenger, 3=passengerCount, 4=pickup, 5=drop, 6=vias, 7=details, 8=bookingId | **YES** — Twilio content SID is Ace-specific, from number hardcoded |
| W2 | `SendWhatsAppUnAllocated` | MessagingService.cs:370 | Driver | Booking unallocated | `HXc42c618c273c5f525d3345d98c11c7fd` | 1=passengerName, 2=date | **YES** — Twilio content SID is Ace-specific |
| W3 | `SendWhatsAppCancelled` | MessagingService.cs:356 | Driver | Booking cancelled | `HX21ff0cd5636f6b00988dcf33edb18073` | 1=passengerName, 2=date | **YES** — Twilio content SID is Ace-specific |
| W4 | `SendWhatsAppBookingAmended` | MessagingService.cs:461 | Driver | Booking amended | `HX39f0bb50e4c814a34da3980fedfa684b` | 1=passengerName, 2=date | **YES** — Twilio content SID is Ace-specific |
| W5 | `SendWhatsAppMessage` (base) | MessageService.cs:192 | Any | Ad-hoc WhatsApp send | N/A (freeform body) | toNumber, message | **YES** — from number `whatsapp:+441747822228` hardcoded |
| W6 | `SendWhatsApp` (base, template) | MessageService.cs:219 | Any | Template-based WhatsApp | *(caller-provided)* | toNumber, variables dict, templateId | **YES** — messaging service SID `MGb33701de6a1ab01db5fb77e5db3b4def` hardcoded, phone exclusions |

### WhatsApp Reply Handling

`ReceiveWhatsAppReply` (Features/WhatsApp/ReceiveWhatsAppReply.cs) handles incoming WhatsApp replies via Twilio webhook (`POST /api/WhatsApp/RecieveReply`). It processes:
- **ACCEPT** button payload: Updates booking status to `AcceptedJob`
- **REJECT** button payload: Updates booking status to `RejectedJob`, unsets driver, creates UI notification

The reply phone number is converted from `whatsapp:+44xxx` to `0xxx` UK format for driver lookup.

---

## 4. Push Notifications (Android FCM)

Android push notifications sent via **Firebase Cloud Messaging (FCM)** through `PushNotificationService.SendAndroidNotification`. Each notification includes a title, body, data payload, and list of FCM registration tokens.

| # | Location | File | Recipient | Trigger | Title | Body | Data Payload | ACE-SPECIFIC? |
|---|----------|------|-----------|---------|-------|------|--------------|---------------|
| P1 | DispatchService (AllocateBooking) | DispatchService.cs:~414 | Driver (allocated) | Booking allocated / job offer | `Job Offer.` | `{date} {asap}\r\n{PickupAddress}, {PickupPostCode}\r\nDropping:\r\n{DestinationAddress},{DestinationPostCode}` | type, bookingId, pickup, destination, date, lat, lng, dlat, dlng, passenger, vias, scope, price, guid | No |
| P2 | DispatchService (AmendBooking) | DispatchService.cs:~556 | Driver (allocated) | Booking amended | `BOOKING AMENDED` | `Your booking on {PickupDateTime} for passenger {PassengerName} has been amended.` | type, bookingId, pickup, destination, passenger | No |
| P3 | DispatchService (UnallocateBooking) | DispatchService.cs:~658 | Driver (was allocated) | Booking unallocated | `Job Unallocated.` | `{date}\r\n{PickupAddress}, {PickupPostCode}\r\nDropping:\r\n{DestinationAddress},{DestinationPostCode}` | type, bookingId, pickup, destination, passenger | No |
| P4 | DispatchService (CancelBooking) | DispatchService.cs:~763 | Driver (was allocated) | Booking cancelled/COA | `Booking {type}` (where type = "COA" or "Cancelled") | `Your booking on {PickupDateTime} for passenger {PassengerName} has been {type}.` | type, bookingId, pickup, destination, passenger | No |
| P5 | DispatchService (JobOfferTimeout) | DispatchService.cs:~976 | Driver (re-offer) | Job offer timed out, re-sending | `Job Offer (R{attempts}).` | *(reuses original offer body from P1)* | *(reuses original offer data)* | No |
| P6 | AdminUIService (SendGlobalMessage) | AdminUIService.cs:~72 | Driver (all with FCM) | Admin sends global message | `GLOBAL MESSAGE` | `{message}` | type, bookingId, message, datetime, sentBy | No |
| P7 | AdminUIService (SendDriverMessage) | AdminUIService.cs:~133 | Driver (specific) | Admin sends direct message | `DIRECT MESSAGE` | `{message}` | type, bookingId, message, datetime, sentBy | No |

---

## 5. Browser Push Notifications (Chrome FCM)

Browser push notifications sent via `PushNotificationService.SendChromeNotification` to all users with a `ChromeFCM` token in their profile. These appear in the dispatch console browser.

| # | Method / Caller | File | Recipient | Trigger | Title | Body | ACE-SPECIFIC? |
|---|----------------|------|-----------|---------|-------|------|---------------|
| B1 | `SendBrowserNotification` via CreateWebBooking | Features/WebBookings/CreateWebBooking.cs:62 | Dispatch operators | Account booking request created | `ACCOUNT BOOKING REQUEST` | `Account {AccNo} has requested a booking for {PickupDateTime}.` | No |
| B2 | `SendBrowserNotification` via CreateCashBooking | Features/WebBookings/CreateCashBooking.cs:87 | Dispatch operators | Cash booking request created | `CASH BOOKING REQUEST` | `Account {AccNo} has requested a booking for {PickupDateTime}.` | No |
| B3 | `SendBrowserNotification` via RequestCancellation | Features/WebBookings/RequestCancellation.cs:52 | Dispatch operators | Account cancellation request | `BOOKING CANCELLATION REQUEST` | `Account {Username} has requested a cancellation.` | No |
| B4 | `SendBrowserNotification` via DispatchService (timeout) | DispatchService.cs:~956 | Dispatch operators | Job offer timed out | `Job Offer (Timed Out)` | `{fullname} did not respond to the job offer within the allowed timeframe.` | No |
| B5 | `SendBrowserNotification` (test) | Features/AdminUI/GetBrowserFCMs.cs:32 | Dispatch operators | GetBrowserFCMs endpoint hit | `test title` | `test body` | No (test only) |

---

## 6. Messaging Configuration

### Channel Routing (MessagingNotifyConfig table)

The `MessagingNotifyConfig` database table controls which channel (None/WhatsApp/SMS/Push) is used for each event type. This is configurable per-tenant at runtime:

| Event | Config Field | Options |
|-------|-------------|---------|
| Driver on allocate | `DriverOnAllocate` | None, WhatsApp, Sms, Push |
| Driver on unallocate | `DriverOnUnAllocate` | None, WhatsApp, Sms, Push |
| Driver on amend | `DriverOnAmend` | None, WhatsApp, Sms, Push |
| Driver on cancel | `DriverOnCancel` | None, WhatsApp, Sms, Push |
| Customer on allocate | `CustomerOnAllocate` | None, WhatsApp, Sms, Push |
| Customer on unallocate | `CustomerOnUnAllocate` | None, WhatsApp, Sms, Push |
| Customer on amend | `CustomerOnAmend` | None, WhatsApp, Sms, Push |
| Customer on cancel | `CustomerOnCancel` | None, WhatsApp, Sms, Push |
| Customer on complete | `CustomerOnComplete` | None, WhatsApp, Sms, Push |

### Infrastructure

| Component | Provider | Config |
|-----------|----------|--------|
| SMS (direct) | TextLocal | `Sms:ApiKey`, `Sms:Sender`, `Sms:Testing` |
| SMS (queued) | RabbitMQ + Android Gateway | `RabbitMQ:Username`, `RabbitMQ:Password`, `RabbitMQ:Host`, `RabbitMQ:Exchange` |
| Email | SendGrid | `Email:Sender`, `Email:SenderName`, `Email:SendGridApiKey` |
| Email (support ticket) | SMTP direct | `Smtp:Host`, `Smtp:Email`, `Smtp:Password` |
| WhatsApp | Twilio | `Twilio:TWILIO_ACCOUNT_SID`, `Twilio:TWILIO_AUTH_TOKEN` |
| Push (Android) | Firebase FCM | `Push:FcmApiKey` |
| Push (Browser) | Firebase FCM | `Push:VapIdPublicKey`, `Push:VapIdPrivateKey`, `Push:VapSubject` |
| URL shortening | Self-hosted | Hardcoded domain `http://pay.acetaxisdorset.co.uk/u/` |

---

## 7. Summary Statistics

| Metric | Count |
|--------|-------|
| **Total notification methods** | **44** |
| SMS notifications | 19 (S1-S19) |
| Email notifications | 18 (E1-E18) |
| WhatsApp notifications | 6 (W1-W6) |
| Push notifications (Android) | 7 (P1-P7) |
| Browser push notifications | 5 (B1-B5) |
| **ACE-SPECIFIC notifications** | **31** |
| SMS with Ace branding | 12 of 19 |
| Email with Ace branding | 18 of 18 (all subjects) |
| WhatsApp with Ace-specific config | 6 of 6 (all — Twilio SIDs, from number) |
| Push with Ace branding | 0 of 7 |
| Browser push with Ace branding | 0 of 5 |

### Key Files

| File | Path |
|------|------|
| Main messaging service | `RedTaxi.Application/Services/MessagingService.cs` |
| Base message service (SMS, Email, WhatsApp) | `RedTaxi.Infrastructure/Messaging/Services/MessageService.cs` |
| Push notification service | `RedTaxi.Infrastructure/Messaging/Services/PushNotificationService.cs` |
| Email template DTOs | `RedTaxi.Application/DTOs/_MessageTemplates/EmailTemplates.cs` |
| Messaging config | `RedTaxi.Infrastructure/Messaging/Config/MessagingConfig.cs` |
| Notify config model | `RedTaxi.Data/Models/MessagingNotifyConfig.cs` |
| WhatsApp send handler | `RedTaxi.Application/Features/WhatsApp/SendWhatsAppMessage.cs` |
| WhatsApp receive handler | `RedTaxi.Application/Features/WhatsApp/ReceiveWhatsAppReply.cs` |
| WhatsApp controller | `RedTaxi.API/Controllers/WhatsAppController.cs` |
| Dispatch service (push) | `RedTaxi.Application/Services/DispatchService.cs` |
| Admin UI service (push) | `RedTaxi.Application/Services/AdminUIService.cs` |
| Web booking handlers | `RedTaxi.Application/Features/WebBookings/` |

### Hardcoded Values Requiring Multi-Tenancy Migration

| Value | Type | Location(s) |
|-------|------|-------------|
| "Ace Taxis" / "Ace Taxi" | Brand name in SMS/Email subjects | 30+ occurrences across MessagingService.cs |
| `01747 821111` | Phone number | S6 (completed booking SMS) |
| `https://cutt.ly/NefYovLC` | Review URL | S6 (completed booking SMS) |
| `support@acetaxis.raiseaticket.com` | Support email | E18 |
| `http://pay.acetaxisdorset.co.uk/u/` | URL shortener domain | MessagingService.cs:702 |
| `whatsapp:+441747822228` | WhatsApp from number | MessageService.cs:209 |
| `MGb33701de6a1ab01db5fb77e5db3b4def` | Twilio messaging service SID | MessageService.cs:243 |
| `HX...` (4 content SIDs) | Twilio WhatsApp template SIDs | MessagingService.cs (W1-W4) |
| 14 SendGrid template IDs (`d-xxx`) | Email template IDs | MessagingService.cs:300-344 |
| `07870545494`, `07572382366` | Admin notification phone numbers | CreateCashBooking.cs, RequestAmendment.cs |
| `07825350912`, `07738825598` | Phone exclusion list | MessagingService.cs:766, MessageService.cs:228 |
| `ace-routing-key`, `AceTaxis` | RabbitMQ routing/client name | MessagingService.cs:785-789 |
| `[removed hardcoded fallback]` | Short.io API key (obsolete method) | MessagingService.cs:726 |
| `ace.1soft.co.uk` | Short.io domain (obsolete method) | MessagingService.cs:716 |

### Inactive / Dead Code

- **S2** (`SendCustomerOnAllocateSMS`): SendToRabbitMq call is commented out — method builds the message but never sends it
- **S5** (`SendCustomerOnBookingCancelledSMS`): SendToRabbitMq call is commented out — message is never sent
- **S4** (`SendCustomerOnBookingAmendSMS`): Method body is `// ignore` — complete no-op
- **ShorternUrl11**: Marked `[Obsolete]`, previously contained a hardcoded API key fallback for Short.io
