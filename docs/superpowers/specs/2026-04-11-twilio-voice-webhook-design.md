# Twilio Voice Webhook Receiver

**Date:** 2026-04-11
**Status:** Implemented
**Scope:** Receive Twilio Voice status callback webhooks, delegate to existing v1 call event pipeline for dispatch screen pop

---

## Context

The current call events system works for a single tenant (Ace Taxis). An external phone system hits `GET /api/callEvents/CallNotification?caller_id=X&recipient_id=Y`, which looks up the caller's booking history and pushes it to the dispatch screen via Pusher.

This work adds a new v2 endpoint that receives Twilio Voice status callbacks, enabling tenants to use Twilio as their phone provider. The endpoint validates the Twilio signature, extracts the caller data, and delegates to the existing v1 `CallNotification` handler for the booking lookup and Pusher push.

The endpoint is designed to work as the **Status Callback URL** on a Twilio number, firing alongside any primary call handler (Twilio Dev Phone, Studio Flow, or AI voice agent). This separation means adding a voice agent later does not require any changes to the screen pop system.

## Goals

- Receive Twilio Voice status callbacks at a new v2 endpoint
- Validate inbound requests with cryptographic Twilio signature check
- Extract caller ID from Twilio's form-encoded POST data
- Delegate to existing `CallNotification` handler for booking lookup and Pusher push
- Verify end-to-end: call Twilio number, see screen pop in dispatch
- Fix Pusher 10KB payload limit (slim booking data before push)
- Fix pre-existing Substring bug in CallNotification handler
- Update headless dispatch to use correct Pusher app/channel/event

## Design

### Endpoint

```
POST /api/v2/call-events/incoming?org={orgId}
```

- `[ApiController]`, `[AllowAnonymous]` (no JWT -- Twilio webhooks have no auth token)
- `[ValidateTwilioRequest]` for cryptographic X-Twilio-Signature validation
- `[Consumes("application/x-www-form-urlencoded")]` -- Twilio sends form data

### Twilio Number Configuration

The endpoint is configured as the **Status Callback URL** (not the primary Voice URL):

- **Voice URL ("A call comes in")** -- reserved for call handling (Dev Phone, AI agent, Studio Flow)
- **Status Callback ("Call status changes")** -- our endpoint, fires on each status transition

This design allows the screen pop to work independently of whatever handles the actual call.

### Status Filtering

Twilio sends status callbacks for: `initiated`, `ringing`, `in-progress`, `completed`, `busy`, `no-answer`, `canceled`, `failed`.

The endpoint triggers the screen pop on: `ringing`, `in-progress`, `completed`.
It ignores: `initiated`, `busy`, `no-answer`, `canceled`, `failed`.

Note: When used as a Status Callback alongside Twilio Dev Phone, only `completed` is received (dev phone intercepts intermediate statuses). In production with a real handler, `in-progress` fires on answer.

### Request Flow

1. Twilio receives an inbound call to the tenant's number
2. Primary handler (Dev Phone/AI agent) handles the call
3. Twilio POSTs status callback to `https://{api}/api/v2/call-events/incoming?org={orgId}`
4. `ValidateTwilioRequest` validates the signature using the Twilio auth token
5. Controller filters by status (only ringing/in-progress/completed trigger screen pop)
6. Controller checks for anonymous/withheld callers -- normalises to `"(anonymous)"`
7. Controller extracts `From` field and normalises to UK format before delegation
8. Controller sets `HttpContext.Items["TenantOrgId"]` from `?org=` query parameter
9. Delegates to `CallNotification.Query(normalisedCallerId, recipientId)` via MediatR
10. Handler queries bookings (slimmed to fit 10KB Pusher limit), pushes to tenant-scoped Pusher channel
11. Controller returns 200 OK

### Phone Number Normalisation

Twilio sends numbers in E.164 format (`+447572382366`). The existing `CallNotification` handler's DB queries match on UK format (`07572382366`). Normalisation happens in the controller before delegation:
- `+447572382366` -- strip `+44`, prepend `0` -- `07572382366`
- `447572382366` -- strip `44`, prepend `0` -- `07572382366`
- `07572382366` -- use as-is
- `+35312345678` -- strip `+` -- `35312345678` (international, may not match DB)
- `Anonymous` / empty -- `(anonymous)`

### Pusher Payload Size Fix

The CallNotification handler previously sent the full Booking entity (including Vias navigation property) which could exceed Pusher's 10KB event limit. Fixed by:
1. Projecting current bookings to slim DTOs (same fields as previous bookings)
2. Limiting to 5 distinct addresses per category
3. If payload still exceeds 9KB, further trimming to 3 per category

### Dispatch Pusher Channel Fix

The headless dispatch had a hardcoded old Pusher app key (`8d1879146140a01d73cf`) subscribing to `my-channel`/`my-event`. Updated to use env vars and the correct tenant-scoped channel:
- Pusher key from `VITE_PUSHER_KEY` (matching backend: `72a68ffd46f37a9d649a`)
- Channel: `tenant-{VITE_TENANT_ORG_ID}`
- Event: `call-event`

### Twilio Number Setup

Configure the number's **Status Callback URL** (not Voice URL):
- **Staging (UK +44 1747 441405):** `https://staging-api.redtaxi.co.uk/api/v2/call-events/incoming?org=org_3BfMRNcpn9933cL6snGXJ7k1PAN`
- **Production:** `https://api.redtaxi.co.uk/api/v2/call-events/incoming?org={tenantOrgId}`

## Files Changed

| File | Action |
|------|--------|
| `RedTaxi.API/Controllers/V2/CallEventsController.cs` | **NEW** -- v2 status callback endpoint |
| `RedTaxi.Notifications/Adapters/TwilioVoiceCallback.cs` | **NEW** -- Twilio voice DTO |
| `RedTaxi.Application/Features/CallEvents/CallNotification.cs` | **MODIFIED** -- Pusher payload slimming, Substring(3) fix |
| `RedTaxi.API/Program.cs` | **MODIFIED** -- dev token endpoint available in Staging mode |
| `headless-dispatch/src/pages/Pusher.jsx` | **MODIFIED** -- correct Pusher key/channel/event |
| `headless-dispatch/.env.staging` | **MODIFIED** -- added VITE_TENANT_ORG_ID |

## Testing (Verified)

1. Twilio number status callback configured via API
2. Called from +447572382366 -- webhook received, caller normalised to 07572382366
3. Dispatch screen pops with caller's booking history (verified on staging)
4. Unsigned requests return 403 (ValidateTwilioRequest working)
5. Pusher 10KB limit handled -- payload slimmed, trimmed if still too large
6. Works alongside Twilio Dev Phone (fires on `completed` status)

## Voice Agent Compatibility

The Status Callback architecture is designed for future AI voice integration:

| Concern | Voice URL | Status Callback |
|---------|-----------|-----------------|
| **Purpose** | AI voice agent / IVR | Screen pop to dispatch |
| **When it fires** | Once, when call arrives | On each status change |
| **Independence** | Handles the call | Notifies dispatch |

Adding a voice agent only requires changing the Voice URL -- no changes to the screen pop system.

## Future Work

- AI voice integration (Voice URL handler)
- Per-tenant call settings (forwarding number, greeting)
- Call recording and transcription
- Support for non-Twilio phone providers
- Rate limiting for webhook endpoints
- Caller Name Lookup (CNAM) enablement
