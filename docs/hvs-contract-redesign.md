# HVS / School Contract Redesign Plan

## Current State

"HVS" stands for Harbour Vale School — a school transport contract handled by Ace Taxis. The system has special pricing logic for these accounts that is **entirely hardcoded by account number** (`9014`, `10026`, `10031`).

This document maps the current hardcoded state and proposes how to make it configurable for multi-tenant SaaS.

## What's Done (Sub-project 1)

- `AccountContractType` enum added to Account model: `Standard (0)` / `SchoolContract (1)`
- EF migration created + existing HVS accounts marked as SchoolContract
- Admin-v2 account form has Contract Type dropdown
- Account list shows "School" badge for SchoolContract accounts

**NOT done yet:** The pricing routing still checks account numbers, not ContractType.

---

## Hardcoded Account Number Checks (8+ files)

These all need replacing with `account.ContractType == SchoolContract`:

| File | Lines | Check |
|------|-------|-------|
| `BookingsController.cs` | ~160 | `obj.AccountNo == 9014 \|\| obj.AccountNo == 10026 \|\| obj.AccountNo == 10031` |
| `StatementProcessingController.cs` | 51-58 | Same check → routes to GetHVSPrice |
| `InvoiceProcessingController.cs` | 48-55 | Same check → routes to GetHVSPrice |
| `AccountsService.cs` | 1657, 1854, 1913, 1930 | HVS pricing logic + passenger adjustments |
| `BookingService.cs` | 162-180 | ShowHVSBookings filter |
| `BookingService.cs` | 2199-2204 | Merge pricing surcharge |
| `Move9014To10026.cs` | 45 | Migration utility |

## How HVS Pricing Differs

| Feature | Standard Account | School Contract |
|---------|------------------|-----------------|
| Pricing source | AccountTariff table | Per-mile rates (hardcoded) |
| Distance calc | Single direction (A→B) | Averaged both ways (A→B + B→A) / 2 |
| Dead mileage | Simple add | Averaged both ways |
| Driver discount | None | 15% (× 0.85) |
| Per-passenger surcharge | None | £7 driver / £15 account per via |
| Postcode exclusion | None | DT9 4DN (no surcharge) |
| Waiting time | Global rate | Same global rate (for now) |

## Proposed Sub-projects

### Sub-project 2: School Contract Tariff Entity

Create a `SchoolContractTariff` table:

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| Id | int PK | auto | |
| Name | string | "School Contract" | Display name (replaces HvsTariffName) |
| DriverPerMileRate | decimal | 2.40 | Per-mile rate for driver |
| AccountPerMileRate | decimal | 2.60 | Per-mile rate for account billing |
| DriverDiscountPercent | decimal | 15 | Discount applied to driver price |
| PerPassengerSurchargeDriver | decimal | 7 | Per-via surcharge (driver) |
| PerPassengerSurchargeAccount | decimal | 15 | Per-via surcharge (account) |
| PostcodeExclusion | string | "DT9 4DN" | Postcode(s) excluded from surcharges |
| DriverWaitingPricePerMin | decimal | 0.33 | Waiting charge (driver) |
| AccountWaitingPricePerMin | decimal | 0.42 | Waiting charge (account) |

Link to Account: `Account.SchoolContractTariffId` (nullable FK, only set for SchoolContract accounts).

Admin-v2 UI: New "School Contract Tariffs" CRUD page under Settings. When an account is marked SchoolContract, assign a tariff.

### Sub-project 3: Per-Tariff Waiting Charges

Currently `DriverWaitingPricePerMin` and `AccountWaitingPricePerMin` are global tenant config. They should be per-tariff:
- Standard AccountTariff: add waiting charge fields
- SchoolContractTariff: already has them (sub-project 2)
- Fallback: tenant config values used if tariff doesn't specify

### Sub-project 4: Replace All Hardcodes

- Replace `accountNo == 9014` checks with `account.ContractType == SchoolContract`
- Replace hardcoded pricing values with SchoolContractTariff lookup
- Replace `GetHVSPrice.cs` to read from SchoolContractTariff entity
- Replace `TariffService.GetPriceHVS()` to read from SchoolContractTariff
- Update `ShowHVSBookings` to use ContractType instead of account numbers
- Rename UI references from "HVS" to "School Contract" where appropriate

---

## Order of Implementation

1. ✅ **Sub-project 1** — Account ContractType flag (DONE)
2. ✅ **Sub-project 2** — SchoolContractTariff entity + CRUD page + account form dropdown (DONE)
3. ✅ **Sub-project 3** — Per-tariff waiting charges on AccountTariff + SchoolContractTariff (DONE)
4. ✅ **Sub-project 4** — Replace all hardcodes (DONE)
   - GetHVSPrice renamed to GetSchoolContractPrice
   - AccountContractResolver service created for DB-backed ContractType checks
   - All 10 pricing routing checks replaced (3 controllers, 3 handlers, 2 AccountsService, 2 BookingService)
   - AcceptWebBooking OR bug fixed (HVS pricing was never reached)
   - BookingService merge surcharge now reads from SchoolContractTariff entity
   - Only Move9014To10026 utility + test fixtures still reference account numbers

All complete. GetSchoolContractPrice + TariffService.GetSchoolContractPrice now read from the SchoolContractTariff entity. TariffService.GetPriceHVS renamed to GetSchoolContractPrice. Per-tariff waiting charges implemented with no global fallback. Completed 2026-04-06.
