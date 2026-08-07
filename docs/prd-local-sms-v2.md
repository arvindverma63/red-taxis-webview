# PRD: Local SMS Sender v2 — Android App + Admin Settings

**Version:** 1.1
**Date:** 2026-04-07
**Status:** Part 1 (Admin backend + frontend) COMPLETE. Part 2 (Android app) COMPLETE — tested on device.

## Overview

Replace the v1 RabbitMQ-based local SMS sender (Windows console app) with a v2 Android app that polls the Red Taxi API for outbound SMS messages and sends them using the phone's native SIM card. The phone IS the SMS gateway — no third-party SMS APIs involved.

This is used for **driver-related messages only** (shift reminders, booking notifications, amendments). Customer-facing messages go through Webex/Twilio separately and are NOT part of this system.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────┐
│  Red Taxi API    │  poll   │  Android App     │  send   │  Driver's   │
│  OutboundMessages├────────►│  (Local SMS v2)  ├────────►│  Phone      │
│  table           │◄────────┤  Native SmsManager│         │  (receives  │
│                  │ status  │                  │         │   SMS)      │
└─────────────────┘         └──────────────────┘         └─────────────┘
                                    ▲
                                    │ QR scan provisions
                                    │ API URL + token + poll interval
                            ┌───────┴──────┐
                            │  Admin Panel  │
                            │  QR Code +    │
                            │  Settings     │
                            └──────────────┘
```

## Part 1: Admin Panel (Red Taxi team builds this)

### 1.1 New Settings Page: `/settings/local-sms`

**Nav item:** "Local SMS" in Settings section (icon: Smartphone)

**Card 1: SMS Device Configuration**
- **API Token** — read-only field showing the current long-lived token (masked, with copy button)
- **Generate Token** button — creates a new non-expiring JWT for the local SMS app. Overwrites any previous token. Confirmation dialog ("This will invalidate the current device").
- **Polling Frequency** — number input (seconds), default 10, min 5, max 60. Saved to `TenantSettings` as `LocalSmsPollInterval`.
- **QR Code** — auto-generated QR code containing a JSON payload:
  ```json
  {
    "apiUrl": "https://api.redtaxi.co.uk",
    "token": "eyJhbG...",
    "pollInterval": 10
  }
  ```
  QR code regenerates when token or poll interval changes. Downloadable as PNG.

**Card 2: Device Status**
- **Status indicator:** Green dot "Online" / Red dot "Offline" (based on last heartbeat)
- **Last Heartbeat:** timestamp, e.g. "12 seconds ago"
- **Messages Today:** count of Sent messages in last 24h
- **Failed Today:** count of Failed messages in last 24h
- Online = heartbeat within last 60 seconds. Offline = no heartbeat for 60+ seconds.

### 1.2 Backend: Token Generation

**New endpoint:** `POST /api/v2/settings/local-sms/generate-token`

Generates a non-expiring HS256 JWT with:
- `sub`: "local-sms-device"
- `tenant_org_id`: current tenant's org_id
- `role`: "LocalSms" (new role — only has access to outbound message endpoints)
- No `exp` claim (non-expiring)

Stores the token hash in `TenantSettings` as `LocalSmsTokenHash` so it can be validated/revoked.

**New endpoint:** `GET /api/v2/settings/local-sms`

Returns:
```json
{
  "success": true,
  "data": {
    "hasToken": true,
    "pollInterval": 10,
    "lastHeartbeat": "2026-04-06T14:30:00Z",
    "messagesToday": 42,
    "failedToday": 1
  }
}
```

**New endpoint:** `PUT /api/v2/settings/local-sms`

Saves `pollInterval` to TenantSettings.

### 1.3 Backend: Heartbeat

**New endpoint:** `POST /api/v2/messaging/outbound/heartbeat`

Called by the Android app on every poll cycle. Updates `LocalSmsLastHeartbeat` in TenantSettings with the current UTC timestamp.

### 1.4 Existing Endpoints (already built)

These already exist and the Android app will use them:

- `GET /api/v2/messaging/outbound?limit=50` — get pending messages
- `PUT /api/v2/messaging/outbound/{id}/status` — mark as Sent(1) or Failed(2)

## Part 2: Android App (Codex builds this)

### 2.1 Provisioning Flow

1. App launches → shows "Scan QR Code to connect" screen
2. User scans the QR code from admin panel
3. App parses JSON: `{ apiUrl, token, pollInterval }`
4. App stores config in SharedPreferences (encrypted)
5. App shows main dashboard screen
6. If config already exists, skip to dashboard on launch

**Reset:** Settings menu with "Reset Configuration" option that clears stored config and returns to QR scan screen.

### 2.2 Main Dashboard UI

```
┌─────────────────────────────┐
│  🟢 Connected               │
│  api.redtaxi.co.uk          │
│                              │
│  ┌─────────┐ ┌─────────┐   │
│  │ Sent    │ │ Failed  │   │
│  │   42    │ │    1    │   │
│  └─────────┘ └─────────┘   │
│                              │
│  ┌─────────┐                │
│  │Processed│                │
│  │   43    │                │
│  └─────────┘                │
│                              │
│  Next poll in: 7s            │
│  Last poll: 3s ago           │
│                              │
│  ── Recent Activity ──       │
│  ✅ 07825350912 - Sent       │
│  ✅ 07738825598 - Sent       │
│  ❌ 07912345678 - Failed     │
│                              │
│           [Stop Polling]     │
└─────────────────────────────┘
```

- **Status indicator:** Green "Connected" / Red "Disconnected" (based on last successful API call)
- **Counters:** Sent, Failed, Processed (since app launch, reset on restart)
- **Countdown timer:** Visual countdown to next poll
- **Recent activity log:** Last 20 messages with status (scrollable)
- **Stop/Start Polling toggle:** Pause/resume without closing app

### 2.3 Polling Loop

```
Every {pollInterval} seconds:
  1. POST /api/v2/messaging/outbound/heartbeat
  2. GET /api/v2/messaging/outbound?limit=50
  3. For each message:
     a. Send SMS via Android SmsManager using phone's SIM
     b. PUT /api/v2/messaging/outbound/{id}/status
        - Status 1 (Sent) if SmsManager returns success
        - Status 2 (Failed) with errorMessage if it fails
  4. Update UI counters
  5. Wait for next interval
```

### 2.4 SMS Sending

Use Android's `SmsManager` API:
```kotlin
val smsManager = SmsManager.getDefault()
smsManager.sendTextMessage(recipient, null, messageBody, sentIntent, deliveryIntent)
```

- Register `BroadcastReceiver` for `sentIntent` to detect send success/failure
- If message is >160 chars, use `sendMultipartTextMessage()`
- Handle permissions: `SEND_SMS` permission must be granted at runtime

### 2.5 Error Handling

- **Network failure:** Retry on next poll cycle. Don't mark messages as Failed for transient network errors.
- **SMS send failure:** Mark as Failed with error message from Android.
- **Token expired/revoked:** Show "Authentication failed — re-scan QR code" and return to provisioning screen.
- **API unreachable:** Show "Disconnected" status. Keep retrying on poll interval.

### 2.6 Tech Stack

- **Language:** Kotlin
- **Min SDK:** 26 (Android 8.0)
- **HTTP:** OkHttp or Retrofit
- **QR Scanner:** ML Kit or ZXing
- **Storage:** EncryptedSharedPreferences
- **Background:** WorkManager for reliable polling (survives app backgrounding)

## Data Flow

```
Admin generates token → QR code displayed → Phone scans QR
Phone polls API → Gets pending messages → Sends via SIM → Reports status
Admin dashboard shows heartbeat + message counts
```

## Files to Create/Modify

### Admin (Red Taxi team)
| File | Action |
|------|--------|
| `src/backend/RedTaxi.API/Controllers/V2/LocalSmsController.cs` | **New** — token generation, settings, heartbeat |
| `src/frontend/apps/admin-v2/src/app/(dashboard)/settings/local-sms/page.tsx` | **New** — settings page with QR code |
| `src/frontend/apps/admin-v2/src/lib/navigation.ts` | Add nav item |

### Android App (Codex team)
| File | Action |
|------|--------|
| `src/mobile/local-sms-v2/` | **New** Android project |
| Provisioning screen (QR scan) | **New** |
| Dashboard screen (counters, log) | **New** |
| API client (poll, heartbeat, status) | **New** |
| SMS sender (SmsManager wrapper) | **New** |

## Out of Scope

- Customer-facing SMS (handled by Webex/Twilio)
- WhatsApp messages
- Multi-device support
- Device registration/naming
- SMS delivery reports (we track send success only, not delivery confirmation)
- Push notifications to admin when device goes offline

## Implementation Status

### Part 1: Admin Panel — COMPLETE
- `POST /api/v2/settings/local-sms/generate-token` — token generation endpoint
- `GET /api/v2/settings/local-sms` — settings + device status
- `PUT /api/v2/settings/local-sms` — save poll interval
- `POST /api/v2/messaging/outbound/heartbeat` — heartbeat endpoint
- Admin sidebar widget: live SMS device status with signal indicators
- Settings page at `/settings/local-sms` with QR code generation

### Part 2: Android App — COMPLETE
Built at `src/mobile/local-sms-v2/`. Kotlin + Jetpack Compose, min SDK 26.

| Component | File | Status |
|-----------|------|--------|
| Gradle build | `build.gradle.kts`, `settings.gradle.kts` | Done |
| API client | `data/api/SmsApi.kt`, `ApiClient.kt` | Done — Retrofit + OkHttp, Bearer auth |
| Config storage | `data/config/AppConfig.kt` | Done — EncryptedSharedPreferences |
| QR provisioning | `ui/provisioning/QrScannerScreen.kt` | Done — ML Kit + CameraX, manual setup option |
| SMS sender | `sms/SmsSender.kt` | Done — SmsManager, multipart, BroadcastReceiver |
| Polling | `polling/PollWorker.kt`, `PollingScheduler.kt` | Done — coroutine loop + WorkManager backup |
| Dashboard | `ui/dashboard/DashboardScreen.kt` | Done — giant status banner, counters, countdown, activity log |
| ViewModel | `ui/dashboard/SmsViewModel.kt` | Done — sequential poll→countdown loop |

**Tested on device:** 2026-04-07, Samsung device, QR scan provisioning verified, API polling verified.

### Remaining Work
- `LocalSms` auth role not yet in production auth policy — app currently requires an Admin-role token
- Test QR page at `src/mobile/local-sms-v2/test-qr.html` for dev testing with admin token
