# Red Taxi — Smoke Test Plan

**Date:** 2026-03-27
**Status:** Planning
**Goal:** Capture real API request/response pairs for automated regression testing.

---

## Problem

We have 236+ API endpoints, no integration tests, and a live frontend relying on
the API. Every change risks breaking something silently. We need automated smoke
tests that verify endpoints return the same shape and status codes after changes.

---

## Approach: Request/Response Recording

### Phase A: Record (capture baseline)

Add middleware that logs every API request/response to a JSON file:

```csharp
// SmokeTestRecorderMiddleware.cs
// Only active in Development when RECORD_SMOKE_TESTS=true
//
// Captures:
// - HTTP method + route
// - Request headers (minus Authorization value)
// - Request body
// - Response status code
// - Response body (first 10KB)
// - Response time
//
// Saves to: smoke-tests/recorded/{controller}/{action}.json
```

**How to use:**
1. Set `RECORD_SMOKE_TESTS=true` in `.env`
2. Run the API locally
3. Use the Admin and Dispatch frontends normally — click through every screen
4. The middleware records every unique endpoint call
5. Stop recording — you now have a baseline of real request/response pairs

### Phase B: Replay (automated regression)

Convert recorded pairs into xUnit integration tests:

```csharp
// Generated test per recorded endpoint:
[Fact]
public async Task Bookings_DateRange_Returns200_WithExpectedShape()
{
    var response = await _client.PostAsync("/api/Bookings/DateRange",
        JsonContent.Create(new { from = "2026-03-01", to = "2026-03-27" }));

    Assert.Equal(HttpStatusCode.OK, response.StatusCode);

    var json = await response.Content.ReadFromJsonAsync<JsonElement>();
    Assert.True(json.TryGetProperty("bookings", out _));
    Assert.True(json.TryGetProperty("totalCount", out _));
}
```

Tests verify:
- ✅ Status code matches recorded baseline
- ✅ Response JSON has the same top-level properties
- ✅ Response is valid JSON (not an exception string)
- ❌ Does NOT compare exact values (data changes)

### Phase C: CI Integration

Run smoke tests on every PR:
```yaml
# .github/workflows/smoke-tests.yml
- run: dotnet test RedTaxi.Tests --filter "Category=Smoke"
```

---

## Implementation Plan

| Step | What | Effort |
|------|------|--------|
| A1 | Create `SmokeTestRecorderMiddleware` | 1 hour |
| A2 | Add toggle via env var `RECORD_SMOKE_TESTS` | 10 min |
| A3 | Record baseline by clicking through all frontend screens | 2 hours |
| B1 | Create test generator script (reads JSON → writes xUnit tests) | 2 hours |
| B2 | Generate tests from recorded baseline | 10 min |
| B3 | Run tests, fix any that fail on clean data | 1 hour |
| C1 | Add GitHub Actions workflow | 30 min |

**Total: ~7 hours**

---

## Alternative: Manual Smoke Test Script

If the middleware approach is too much upfront, a simpler option:

Create `smoke-test.sh` that curls every endpoint and checks status codes:

```bash
#!/bin/bash
TOKEN=$(curl -s -X POST "$BASE/api/UserProfile/Login" ...)
PASS=0; FAIL=0

test_endpoint() {
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$@")
    if [ "$STATUS" = "$EXPECTED" ]; then
        echo "  ✅ $NAME"
        ((PASS++))
    else
        echo "  ❌ $NAME (expected $EXPECTED, got $STATUS)"
        ((FAIL++))
    fi
}

# ... one call per endpoint ...

echo "$PASS passed, $FAIL failed"
```

This is lower effort but doesn't validate response shapes.

---

## Recommended Path

1. **Immediately:** Create the shell script smoke test (30 min)
2. **This week:** Add the recording middleware
3. **Next week:** Generate xUnit tests from recorded data
4. **Ongoing:** Run on every PR

---

## Endpoints to Cover (Priority Order)

### Must Test (used by current frontends)
- Login (v1 + v2)
- Bookings/DateRange
- Bookings/Today
- Bookings/Create
- Bookings/Cancel
- Bookings/Update
- Accounts/GetList
- AdminUI/Dashboard
- AdminUI/DriversList
- AdminUI/GetAccounts
- DriverApp/Login + GetProfile + TodayJobs
- Reporting/* (all 13)
- Availability/General
- Address/DispatchSearch

### Should Test (supporting endpoints)
- Bookings/Allocate + Complete
- Accounts/Tariffs + Invoices + Statements
- UserProfile/ListUsers
- LocalPOI/GetPOI
- WebBookings/Create + Accept + Reject

### Can Skip (rarely used or admin-only)
- Bookings/MergeBookings
- AdminUI/Move9014To10026
- SmsQue/GetMessages
- CallEvents/*
