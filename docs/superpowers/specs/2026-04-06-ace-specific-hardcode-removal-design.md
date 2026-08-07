# ACE-SPECIFIC Hardcode Removal — Design Spec

**Date:** 2026-04-06
**Status:** IMPLEMENTED (2026-04-06) — MuteSms, IsSubstituteDriver, OutboundMessage, BankHolidays all deployed

## Problem

31 ACE-SPECIFIC hardcodes remain in the backend. This session tackles 4 areas that block multi-tenant operation:

1. **Hardcoded phone exclusions** in MessagingService (lines 782-783) silently drop SMS to two test numbers
2. **NonAce boolean flag** on UserProfile is confusingly named — means "substitute driver"
3. **RabbitMQ SMS queue** hardcodes credentials and is tightly coupled to Ace's local infrastructure
4. **Bank holiday dates** hardcoded in TariffService/TariffSelector will expire after 2027

## Design

### 1. MuteSms Flag on Driver Profile

**Entity change:** Add `MuteSms` (bool, default false) to `UserProfile`.

**Backend change:** In `MessagingService.SendSmsViaRabbitMQ()` (line 779), replace the hardcoded phone check:
```csharp
// BEFORE: if (packet.Telephone == "07825350912" || packet.Telephone == "07738825598") return true;
// AFTER: check MuteSms flag on driver profile before queueing
```

**Frontend change:** Add "Mute SMS" toggle to driver add/edit form in admin-v2.

**Migration:** EF migration adds `MuteSms` column. Set `MuteSms = true` for the two existing excluded phone numbers.

### 2. NonAce → IsSubstituteDriver Rename

**Entity change:** Rename `UserProfile.NonAce` to `IsSubstituteDriver`.

**Migration:** `RenameColumn("UserProfiles", "NonAce", "IsSubstituteDriver")`.

**Backend changes:** Update all references:
- `MessagingService.cs` line 659: `.Where(o => o.IsSubstituteDriver == false)`
- `UserProfileService.cs` line 260: `IsNonAce()` → `IsSubstituteDriver()`
- All DTOs/responses returning `NonAce` → `isSubstituteDriver`

**Frontend change:** Update admin-v2 driver list/form to show "Substitute Driver" instead of "Non Ace".

### 3. RabbitMQ → OutboundMessage Table (SMS Only)

**New entity:** `OutboundMessage` in tenant DB:
- `Id` (int, PK)
- `Recipient` (string, phone number)
- `MessageBody` (string)
- `Channel` (enum: SMS)
- `Status` (enum: Pending / Sent / Failed)
- `CreatedAt` (DateTime)
- `SentAt` (DateTime?)
- `ErrorMessage` (string?)
- `Attempts` (int, default 0)

**Backend change:** Replace `MessagingService.SendSmsViaRabbitMQ()` with:
```csharp
await _db.OutboundMessages.AddAsync(new OutboundMessage {
    Recipient = phone, MessageBody = body, Channel = MessageChannel.SMS,
    Status = MessageStatus.Pending, CreatedAt = DateTime.UtcNow
});
```

**New API endpoints:**
- `GET /api/v2/messaging/outbound?status=Pending` — local SMS sender polls this
- `PUT /api/v2/messaging/outbound/{id}/status` — mark as Sent/Failed after delivery

**Result:** No RabbitMQ dependency. Local SMS sender app polls the API instead of consuming a queue. Simpler, portable, works for any tenant.

### 4. Bank Holidays → Database Table

**New entity:** `BankHoliday` in tenant DB:
- `Id` (int, PK)
- `Date` (DateOnly)
- `Name` (string, max 100)

**Backend change:** Replace hardcoded dictionary in `TariffService` and `TariffSelector` with:
```csharp
var holidays = await _db.BankHolidays.Select(h => h.Date).ToListAsync();
```

**Migration:** Seed 2025-2028 UK bank holidays.

**Frontend:** Simple CRUD page for managing holidays (can be added later — seed covers immediate need).

## Out of Scope (Follow-up Task)

- Pro Disability account numbers (9005, 9006, 90004) → move to TenantSettings
- Account 10029 email override (mandydabo@icloud.com) → move to TenantSettings
- Hardcoded date cutoffs (2025-09-01, 2025-05-07) → move to TenantSettings
- BookingService server domain → use TenantSettings
- WhatsApp notification pipeline → not being touched

## Files Changed

| File | Change |
|------|--------|
| `UserProfile.cs` | Add `MuteSms`, rename `NonAce` → `IsSubstituteDriver` |
| `OutboundMessage.cs` | **New** entity |
| `BankHoliday.cs` | **New** entity |
| `RedTaxiDbContext.cs` | Add 2 DbSets |
| EF Migration | Add columns + 2 tables + seed bank holidays |
| `MessagingService.cs` | Replace RabbitMQ publish with OutboundMessage insert, replace phone exclusions with MuteSms check |
| `TariffService.cs` | Replace hardcoded holidays with DB query |
| `TariffSelector.cs` | Same |
| `UserProfileService.cs` | Rename IsNonAce → IsSubstituteDriver |
| `MessagingController.cs` (new or existing) | Add outbound message polling endpoints |
| Admin-v2 driver form | Add MuteSms toggle, rename NonAce |
| Admin-v2 driver list | Update column name |
