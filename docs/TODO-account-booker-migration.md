# TODO: Account Booker App — Clerk Migration

**Status:** DEFERRED — do after admin-v2 is complete
**Created:** 2026-04-01

## Context

The account-booker app (`src/frontend/apps/account-booker/`) currently uses custom JWT auth
(username = account number, password = generated). It needs migrating to Clerk auth.

## What's Been Done (Admin v2)

- Web Booker registration page planned for admin v2
- Booker Email / Booker Name fields to be moved from Account form to dedicated Web Bookers page
- Clerk Backend SDK integration needed in .NET API for creating/managing booker users

## What Needs Doing (Account Booker App)

1. **Replace custom auth with Clerk** — swap username/password login for Clerk sign-in
2. **Update the account-booker frontend** — replace Redux auth state with Clerk hooks
3. **Add Clerk keys** to account-booker .env
4. **Test the full flow**: admin creates booker → Clerk sends invite → booker signs in to account-booker app
5. **Remove legacy auth endpoints** — `/Auth/Authenticate`, custom JWT generation

## Admin v2 Page (to build now or next session)

New page: `/accounts/web-bookers` or section within Accounts page
- List accounts with their registered web bookers
- Register: enter email + name → Clerk createUser API → store on Account
- Revoke: remove Clerk user → clear bookerEmail/bookerName on Account
- Clerk Backend SDK calls from .NET API: POST /api/v2/accounts/{accNo}/register-booker
- Remove Booker Email / Booker Name from Account Add/Edit dialog

## Dependencies

- Clerk Backend SDK for .NET (or Clerk REST API via HttpClient)
- Clerk instance must have "account-booker" as an allowed app
- CLERK_SECRET_KEY must be available to the backend
