# Red Taxi — Frontend Team API Migration Brief

**Version:** 1.0  
**Audience:** Frontend Developers  
**Status:** Locked

---

## What Is Happening

The backend API is being refactored — cleaned up, better structured, and prepared
for multi-tenancy. You will not need to make any changes immediately.
Nothing breaks during this process.

When a feature is refactored, a clean v2 endpoint is added alongside the existing
v1 endpoint. Both work. You migrate at your own pace, one endpoint at a time.

---

## The Two-Version Rule

| Version | URL Example | Status |
|---|---|---|
| v1 | /api/v1/bookings | Existing — works today, behaviour unchanged |
| v2 | /api/v2/bookings | New — added when each feature is refactored |

v1 stays alive until you confirm you have migrated off that endpoint. v2 returns
cleaner, consistently structured responses. Bug fixes applied to the handler fix
both v1 and v2 simultaneously — you will not be left behind on fixes.

You will be notified when a v2 endpoint is available for a specific feature.
There is no pressure to migrate immediately.

---

## What Changes in v2 Responses

All v2 endpoints return a consistent envelope. The inconsistent DTO shapes that
vary between v1 endpoints are gone.

```json
// v2 success
{
  "success": true,
  "data": { "bookingId": "uuid", "status": "Created" },
  "errors": []
}

// v2 error
{
  "success": false,
  "data": null,
  "errors": [{ "code": "BOOKING_NOT_FOUND", "message": "Booking not found" }]
}
```

HTTP status codes are also used correctly on v2 across all endpoints — 400 for
validation failures, 401 for unauthenticated, 403 for unauthorised, 404 for not
found, 500 for server errors. Handle errors by checking `success: false` and
reading the `errors` array.

---

## Your Migration Steps Per Endpoint

1. Backend team notifies you that a feature has a v2 endpoint ready
2. Test v2 in your dev environment — verify the response shape matches expectations
3. Switch that feature's calls from `/api/v1/xxx` to `/api/v2/xxx`
4. Confirm to the backend team — they will then retire the v1 route for that feature

Features migrate one at a time. You will not be asked to migrate everything at once.

---

## Current Status

All backend refactoring phases (0–3) are complete. All v2 endpoints are live
alongside the existing v1 endpoints. You can begin migrating to v2 at any time.

| Phase | Status | Frontend Impact |
|---|---|---|
| Phase 0–1 | Complete | None — logging and error handling only |
| Phase 2 | Complete | None — internal project restructure |
| Phase 3 | Complete | All v2 endpoints available — 241 handlers across 16 features |
| Phase 4 | Deferred | None — multi-tenancy deferred until UI verified |

## API Base URL

- **Production:** https://red-taxi-production.up.railway.app
- **Docs (Scalar):** https://red-taxi-production.up.railway.app/scalar/v1
- **Health check:** https://red-taxi-production.up.railway.app/health

---

*Questions? Raise with the backend team before migrating any endpoint.*
