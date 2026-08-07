# Account Booker Registration — Design Spec

**Date:** 2026-04-01
**Status:** Approved
**Author:** Claude + Peter

---

## Problem

V1 used EF Identity to create account booker users with generated passwords. V2 uses Clerk for auth. The admin needs to register/revoke web booker access for accounts, with Clerk handling user onboarding.

## Design

### Accounts Page Changes

- Add "Manage Booker" button (User icon) in the Actions column
- Remove Booker Email and Booker Name fields from the Account Add/Edit form dialog
- When bookerEmail exists on an account, show a subtle indicator in the table row

### Manage Booker Dialog

Triggered by clicking the User icon on an account row.

**If no booker registered (bookerEmail empty):**
- Email input (required)
- Name input (required)
- "Send Invitation" button → POST /api/v2/accounts/{accNo}/register-booker
- On success: Clerk sends onboarding email, account updated, dialog closes

**If booker already registered:**
- Booker email (read-only, copyable)
- Booker name (read-only)
- Last Booked On date (read-only) — latest booking date for this account
- Status badge: "Active" (green) or "Invited" (amber)
- "Revoke Access" destructive button with ConfirmDialog

### Backend Endpoints

**POST /api/v2/accounts/{accNo}/register-booker**
```json
Body: { "email": "booker@company.com", "name": "Jane Smith" }
Response: { "success": true, "data": null, "errors": [] }
```
Flow:
1. Validate email format
2. Call Clerk REST API: POST https://api.clerk.com/v1/invitations
   - Body: { email_address, public_metadata: { role: "Account", accountNo, tenantOrgId } }
3. Update Account: set BookerEmail + BookerName
4. Return success

**DELETE /api/v2/accounts/{accNo}/revoke-booker**
```json
Response: { "success": true, "data": null, "errors": [] }
```
Flow:
1. Read Account to get BookerEmail
2. Call Clerk REST API: GET https://api.clerk.com/v1/users?email_address={email}
3. If Clerk user found: DELETE https://api.clerk.com/v1/users/{userId}
4. Clear BookerEmail + BookerName on Account
5. Return success

**GET /api/v2/accounts/{accNo}/booker-status**
```json
Response: { "success": true, "data": { "hasBooker": true, "email": "...", "name": "...", "lastBookedOn": "2026-03-15T10:30:00" }, "errors": [] }
```
Flow:
1. Read Account for BookerEmail + BookerName
2. Query Bookings: MAX(PickupDateTime) WHERE AccountNumber = accNo AND Cancelled = false
3. Return combined data

### ClerkApiService (Infrastructure)

New service in RedTaxi.Infrastructure wrapping Clerk REST API:
- `SendInvitation(email, metadata)` → POST /v1/invitations
- `FindUserByEmail(email)` → GET /v1/users?email_address=
- `DeleteUser(clerkUserId)` → DELETE /v1/users/{id}
- Uses CLERK_SECRET_KEY from config via HttpClient
- Bearer token auth: `Authorization: Bearer {CLERK_SECRET_KEY}`

### Frontend

**ManageBookerDialog** component:
- Props: account (Account object), open, onOpenChange
- Fetches booker status via GET /api/v2/accounts/{accNo}/booker-status
- Conditional UI: register form vs registered view
- Last Booked On shown as formatted date or "Never" if null
- Toast notifications on all actions

### Files to Create/Modify

**Backend:**
- `RedTaxi.Infrastructure/Services/ClerkApiService.cs` — new
- `RedTaxi.Application/Features/Accounts/RegisterAccountBooker.cs` — new handler
- `RedTaxi.Application/Features/Accounts/RevokeAccountBooker.cs` — new handler
- `RedTaxi.Application/Features/Accounts/GetBookerStatus.cs` — new handler
- `RedTaxi.API/Controllers/V2/AccountsController.cs` — add 3 endpoints
- `RedTaxi.API/Program.cs` — register ClerkApiService in DI

**Frontend:**
- `src/app/(dashboard)/accounts/manage-booker-dialog.tsx` — new
- `src/app/(dashboard)/accounts/page.tsx` — add Manage Booker button
- `src/app/(dashboard)/accounts/account-form-dialog.tsx` — remove BookerEmail/BookerName fields
- `src/lib/hooks/use-accounts.ts` — add booker status/register/revoke hooks

### Future (not built now)
- Dispatch Users management page (Role: User) — same Clerk pattern
- Driver registration update (Role: Driver) — same Clerk pattern
- EF Identity table removal — after all roles migrated to Clerk
