# Red Taxi — Stabilisation Plan

**Date:** 2026-03-27
**Status:** Planning
**Prerequisite:** Phase 3 complete. All changes must be non-breaking.

---

## Guiding Principle

**Do not break anything.** The current frontend apps (Admin, Dispatch, Account Booker,
Headless Dispatch) are actively being used for verification. Every fix must be
backwards-compatible. No auth changes to endpoints that the frontend currently
calls without auth — those are intentional for now.

---

## Track 1: Credential Cleanup (Critical)

Move all hardcoded credentials to environment variables. Zero logic changes.

| # | File | What | Fix | Risk |
|---|------|------|-----|------|
| 1.1 | `TariffService.cs:490` | Google Maps API key hardcoded as `const` | Read from `IConfiguration["Google:PlacesApiKey"]` | None — same key, different source |
| 1.2 | `MessagingService.cs:773-778` | RabbitMQ host/user/pass hardcoded | Read from `IConfiguration["RabbitMQ:*"]`, add to `.env` and Railway | None |
| 1.3 | `GetSmsQueueMessage.cs:41-46` | Duplicate RabbitMQ credentials | Same fix as 1.2 | None |
| 1.4 | `MessagingService.cs` | SMTP server/credentials hardcoded | Read from `IConfiguration["Smtp:*"]`, add to `.env` and Railway | None |

**Env vars to add:**
```
RABBITMQ_HOST=85.234.135.182
RABBITMQ_USERNAME=acetaxis
RABBITMQ_PASSWORD=ace
RABBITMQ_EXCHANGE=AceExchange
SMTP_HOST=smtp.ionos.co.uk
SMTP_EMAIL=bookings@acetaxisdorset.co.uk
SMTP_PASSWORD=<from current source>
```

---

## Track 2: Null Reference Fixes (Critical)

| # | File | Line | What | Fix | Risk |
|---|------|------|------|-----|------|
| 2.1 | `UsersService.cs:110` | `FindById` | Returns `FirstOrDefault` (nullable) but signature says non-null | Return `Task<AppUser?>` and add null check in callers | Low — adds safety, no behaviour change when user exists |
| 2.2 | `AuthenticationService.cs:143-148` | Token refresh | Dereferences `dbuser.Id` without null check | Add `if (dbuser == null) return fail` before access | None — currently crashes, fix returns proper error |
| 2.3 | `BookingService.GetBooking` | FindById | Accesses booking properties without null check | Add `if (booking == null) return null` | None — currently crashes, fix returns 404 |

---

## Track 3: Auth Audit (High — DO NOT CHANGE v1 without frontend verification)

**Status:** ✅ Audited 2026-03-27. No changes made. All v2 endpoints have `[Authorize]`.

**Controllers with ZERO auth (all methods public):**
- `AddressController` (6 endpoints) — used by public booking forms
- `CallEventsController` (5 endpoints) — called by PBX/VoIP system
- `LocalPOIController` (6 endpoints) — used by address search
- `ReportingController` (13 endpoints) — **oversight, should be secured**
- `RedirectController` (1 endpoint) — public URL shortener
- `QRCodeClickCounter` (1 endpoint) — public tracking pixel
- `WhatsAppController` (2 endpoints) — called by Twilio webhook
- `ATestController` (dead code — to be deleted)

### Endpoints with `//[Authorize]` commented out (were secured, intentionally unsecured)

These were **deliberately** unsecured by a developer. Do NOT re-enable without
confirming the frontend doesn't rely on unauthenticated access.

| Controller | Endpoint | Currently | Action |
|-----------|----------|-----------|--------|
| `BookingsController:88` | `FindBookings` | `//[Authorize]` | **Verify with frontend** — if admin-only, re-enable |
| `BookingsController:618` | `SendPaymentLink` | `//[Authorize]` | **Verify** — payment link may be called from web booker without auth |
| `BookingsController:748` | `GetDuration` | `//[Authorize]` | **Verify** — may be called from public web booking form |
| `AdminUIController:120` | `DriversOnShift` | `//[Authorize]` | **Verify** — dispatch may call this without auth |
| `UserProfileController:171` | `GetAllUsersGPS` | `//[Authorize]` | **Verify** — dispatch map may call this without auth |
| `AvailabilityController:32` | `SendReminder` | `//[Authorize]` | Uses hardcoded key `ace@taxis` instead. Keep as-is for now. |
| `WeBookingController:288` | `GetAccountActiveBookings` | `// [Authorize]` | **Verify** — account booker may need unauthenticated access |
| `AccountsController:79` | `GetAccountTariffs` | `//[Authorize]` | **Verify** — may be public for web pricing display |
| `AccountsController:104` | `CreateOrUpdateTariff` | `//[Authorize]` | **Should be secured** — admin-only mutation |

### Endpoints that NEVER had `[Authorize]` (intentionally public or oversight)

| Controller | Endpoints | Likely Reason | Action |
|-----------|-----------|---------------|--------|
| `CallEventsController` | All 5 endpoints | Called by phone system (PBX/VoIP) — no JWT available | Add API key auth later, leave as-is for now |
| `ReportingController` | All 13 endpoints | **Oversight** — reporting data should be secured | **Flag for Phase 5** — adding auth here will break any frontend calling these without a token |
| `WhatsAppController:40` | `Send` | Called by internal systems | Add API key auth later |
| `SmsQueController:19` | `GetMessages` | Called by local SMS gateway | Add API key auth later |
| `LocalPOIController:20-36` | `GetPOI`, `GetPOI2` | May be used by public address search | **Verify with frontend** |
| `LocalPOIController:65` | `Upload` (CSV) | **Oversight** — file upload without auth | **Should be secured** |
| `AdminUIController:39` | `Move9014To10026` | **Oversight** — data mutation without auth | **Should be secured** |
| `AdminUIController:129-429` | ~20 driver/account endpoints | Mixed — some have auth, some don't | **Audit individually** |

### Recommendation

Do NOT change any auth on v1 endpoints until the frontend is verified working.
Instead:
1. Document which endpoints the frontend calls without auth
2. Secure v2 endpoints properly (all v2 controllers already have `[Authorize]` ✅)
3. Add auth to v1 endpoints one-by-one after confirming frontend sends tokens

---

## Track 4: Code Quality (Medium)

| # | What | Fix | Risk |
|---|------|-----|------|
| 4.1 | `MessagingService.cs:683` — `.Result` sync-over-async | Change to `await` | Low — but need to check if caller is sync |
| 4.2 | 5× `new HttpClient()` in services | Register `IHttpClientFactory`, inject `HttpClient` | Low — same behaviour, proper lifecycle |
| 4.3 | 7× `ex.Message` leaked in responses | Replace with generic error message, log full exception | Low — less info to callers, more info in logs |
| 4.4 | Dead code: `ATestController`, `LookupByEmail` | Delete | None |
| 4.5 | `TariffService.cs:671-694` — Bank holidays hardcoded to 2027 | Move to config/DB table | Low — won't break until 2028 |

---

## Track 5: ACE-SPECIFIC Hardcodes (Phase 4 — Deferred)

96 hardcoded values across 11 files. These are the multi-tenancy blockers.
**Do not fix now.** These will be replaced with `ITenantConfig` lookups in Phase 4.

Tracked in: `docs/refactor/class-audit.md` (tagged with `// [ACE-SPECIFIC]`)

---

## Execution Order

```
Track 1 (Credentials)  →  commit + deploy + verify
Track 2 (Null refs)     →  commit + deploy + verify
Track 4 (Code quality)  →  commit + deploy + verify
Track 3 (Auth)          →  ONLY after frontend is verified working
Track 5 (ACE-SPECIFIC)  →  Phase 4
```

Each track is a separate PR. Tests must pass after each.

---

## Success Criteria

- [x] Zero hardcoded credentials in source code (Track 1 — done 2026-03-27). Note: Revolut secret key and Short.io key were later found still in code — moved to env vars in security review.
- [x] Null reference crashes return proper error responses (Track 2 — done 2026-03-27)
- [ ] No `new HttpClient()` in services (Track 4.2 — in progress)
- [ ] No exception details leaked to API callers (Track 4.3 — in progress)
- [x] All v2 endpoints have `[Authorize]` (confirmed 2026-03-27)
- [x] Auth audit documented for v1 endpoints (Track 3 — documented, no changes)
- [x] Frontend apps continue to work identically (manual testing passed 2026-03-27)
