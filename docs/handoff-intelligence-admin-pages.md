# Handoff: Intelligence Admin Management Pages

**Created:** 2026-04-14
**Branch:** `feature/intelligence-admin-pages` (branched from `feature/route-intelligence-cache`)
**Upstream PR:** #30 — route intelligence cache (open, mergeable, awaiting merge to `dev`)
**Goal:** Build admin-v2 management pages for the new route intelligence data + any other intelligence data that's currently read-only.

---

## Why this matters

PR #30 shipped a new `intelligence_routes` table + cache that cuts quote latency from 84–107 ms (Google Distance Matrix) to **1–6 ms** (in-memory). 5,404 bidirectional routes were generated, 676 loaded at high/medium confidence. Airports included (Heathrow T2/T3/T5, Bristol, etc.).

The data is **currently invisible and unmanageable from the admin UI**. Operators can't:
- See which routes are cached vs falling through
- Inspect specific pair prices / mileage / duration
- Correct bad data (e.g. routes with `JourneyMiles=0`, outlier durations like 205 min for 31 mi)
- Force-refresh a specific route or exclude it from the cache
- Tune confidence thresholds

We need management pages modelled on the existing `/intelligence/routes` and `/intelligence/hotlist` pages.

---

## Current state

### Branch & git
- On `feature/intelligence-admin-pages`, based on `feature/route-intelligence-cache`
- `feature/route-intelligence-cache` has 6 commits (5 feature + 1 docs) and is under review as **PR #30 → dev**
- When PR #30 merges, rebase this branch onto `dev`
- **DO NOT** start coding until you've confirmed `git branch --show-current` is `feature/intelligence-admin-pages` and `git log --oneline -10` shows the route-intelligence commits present (`a90fdfc`, `0079557`, `04be2dc`, `6b42943`, `54cb7d2`, `f8a8aa9`)

### Existing intelligence admin pages (reference these for style/pattern)

```
src/frontend/apps/admin-v2/src/app/(dashboard)/intelligence/
├── demand-patterns/page.tsx          # 7x24 heatmap
├── driver-earnings/page.tsx          # dual-axis chart + fairness badges
├── hotlist/page.tsx                  # POI hot list display (read-only)
├── locations/page.tsx                # canonical locations CRUD-ish (merge, edit)
├── pipeline/page.tsx                 # run/backfill controls + stats
├── revenue-by-area/page.tsx          # postcode heatmap + route pairs table
└── routes/page.tsx                   # popular routes list (read-only, OLD — uses `intelligence_popular_routes`)
```

### Existing backend endpoints (in `src/backend/RedTaxi.AI/Intelligence/IntelligenceController.cs`)

```
POST /api/v2/intelligence/run                       # full pipeline
POST /api/v2/intelligence/backfill                  # backfill only
POST /api/v2/intelligence/export                    # export STT bias files
POST /api/v2/intelligence/backfill-with-legacy      # MSSQL-enriched backfill
POST /api/v2/intelligence/incremental               # incremental update
POST /api/v2/intelligence/refresh-mishearing        # reload mishearing rules
POST /api/v2/intelligence/caller-mapping            # map caller phone → location
GET  /api/v2/intelligence/postcode-routes           # routes grouped by postcode
GET  /api/v2/intelligence/locations                 # canonical locations
GET  /api/v2/intelligence/locations/{id}            # location detail
POST /api/v2/intelligence/locations/merge           # merge duplicates
GET  /api/v2/intelligence/routes                    # popular routes (OLD table)
GET  /api/v2/intelligence/hotlist                   # POI hot list dump
GET  /api/v2/intelligence/stats                     # pipeline stats
```

**`GET /api/v2/intelligence/routes` reads the OLD `PopularRoute` table (kept for compatibility). The NEW `IntelligenceRoute` table has no admin endpoints yet.**

---

## What to build

### Part 1 — Backend endpoints for `intelligence_routes`

Add to `src/backend/RedTaxi.AI/Intelligence/IntelligenceController.cs`:

1. **`GET /api/v2/intelligence/route-cache`** — paginated list of `IntelligenceRoute` rows
   - Query params: `search` (postcode contains), `confidence` (high/medium/low/all), `minUsage`, `onlyCached` (JourneyMiles > 0), `page`, `pageSize`, `sortBy` (UsageCount/JourneyMiles/DurationMinutes/UpdatedAt), `sortDir`
   - Response envelope: `{ success, data: { items, totalCount, page, pageSize }, errors }`
   - Each item: Id, PostcodeA, PostcodeB, JourneyMiles, DurationMinutes, Tariff1Price, Tariff2Price, Tariff3Price, UsageCount, Confidence, MedianPrice, PriceStdDev, LastUsed, UpdatedAt
   - Indicate if the row is actively loaded into the cache (matches filter `Confidence != "low" && JourneyMiles > 0`)

2. **`GET /api/v2/intelligence/route-cache/{id}`** — single route detail

3. **`POST /api/v2/intelligence/route-cache/{id}/reload`** — force-recompute this route from historical trips (use the existing Stage 6 aggregation logic, scoped to a single postcode pair)

4. **`DELETE /api/v2/intelligence/route-cache/{id}`** — exclude from cache (soft delete — set a flag the cache loader respects, or hard delete and regenerate)

5. **`POST /api/v2/intelligence/route-cache/reload-cache`** — trigger `IntelligenceCache.ReloadAsync(tenantConnStr)` without running full pipeline. Useful after manual edits.

6. **`GET /api/v2/intelligence/route-cache/stats`** — summary: total routes, high/medium/low counts, % with JourneyMiles > 0, avg usage count, last pipeline run timestamp

**Key files to touch:**
- `src/backend/RedTaxi.AI/Intelligence/IntelligenceController.cs` — add endpoints
- `src/backend/RedTaxi.AI/Intelligence/Services/IntelligenceCache.cs` — may need a `ReloadSingleRoute()` method and/or public access to trigger reload per-tenant
- `src/backend/RedTaxi.AI/Intelligence/Services/JourneyIntelligencePipeline.cs` — extract the Stage 6b logic into a method callable for a single pair
- Look at how `locations/merge` is done (line ~379 of IntelligenceController.cs) for a good pattern for mutations

### Part 2 — Admin-v2 pages

Add a new nav item group under Intelligence. Proposed routes:

1. **`/intelligence/route-cache`** — the main management page
   - Filter bar: search (postcode), confidence (all/high/medium/low), min usage, "only valid cache rows" toggle
   - Stats cards (total routes, loaded in cache, high-confidence %, avg usage, last pipeline run)
   - Paginated table (SortableTableHead + TablePagination, 10/page default — follow admin-v2 rules in `src/frontend/apps/admin-v2/CLAUDE.md`)
   - Columns: Postcodes (A → B with ⇄ icon to indicate bidirectional), Miles, Duration, T1/T2/T3 prices, Usage, Confidence badge, Last Used, Actions (View / Reload / Exclude)
   - Row click → detail drawer/modal

2. **`/intelligence/route-cache/[id]`** — detail page (or drawer)
   - All route fields including MedianPrice and PriceStdDev
   - Link to underlying historical trips (if feasible — trip data is in `intelligence_raw_records` or similar)
   - Actions: Reload single, Exclude from cache

3. **Consider adding to existing pages** (don't duplicate, augment):
   - `/intelligence/pipeline` — add "Reload route cache only" button that calls the new reload endpoint
   - `/intelligence/routes` (old page) — decide whether to deprecate in favour of `/intelligence/route-cache` or keep showing the PopularRoute table alongside

### Part 3 — Other intelligence data that's currently read-only

Audit and flag what else should become manageable:

- **Aliases** (`intelligence_aliases`) — already partially editable via SttComparisonService auto-inserts, but an admin page to review/approve/delete aliases would be useful. Currently 1,944 aliases exist.
- **Speech bias terms** (`intelligence_speech_bias`) — read-only dump on `/intelligence/hotlist`? Operators may want to add/remove terms that are missed or mislearned.
- **Canonical locations** — `/intelligence/locations` exists but check whether the new Tariff data / trip counts are surfaced adequately.
- **Caller mapping** — `POST caller-mapping` endpoint exists but no UI.
- **Demand patterns** — `intelligence_patterns` (3,641 rows). Heatmap page exists (`/intelligence/demand-patterns`) but is read-only. Consider whether tuning thresholds is needed.

### Part 4 — Follow-ups from PR #30 (separate but related)

These are noted in PR #30's body:
- **`ChargeFromBase` should become a company setting** (currently hardcoded `true` in `AiAgentController.cs` line ~365). Admin settings page needs a toggle. Audit `src/frontend/apps/dispatch/` for the same hardcode.
- **Tariff 3 (Christmas) selection logic** is a TODO in the quote fast path (line ~323). Currently only T1/T2 selected. Decide: is this an admin-managed date list? A pattern like "Dec 24-26 + Jan 1"? Company setting?
- **Data quality flags** — some routes have `JourneyMiles=0` or `Tariff1Price=0` (empty Distance Matrix enrichment). Admin page should highlight these. Some routes have outlier durations (e.g. 205 min for 31 mi SP8 5NX→TW6 1EW — likely meter ran post-arrival). The pipeline's median calc should catch most but the UI needs a "data anomalies" view.

---

## Non-negotiable rules (from project CLAUDE.md + admin-v2 CLAUDE.md)

Read these BEFORE writing code:
- `O:\RedTaxi\CLAUDE.md` — backend standards, MediatR handlers, v2 envelope `{success, data, errors}`, no hardcoded tenant IDs, Serilog structured logging
- `O:\RedTaxi\src\frontend\apps\admin-v2\CLAUDE.md` — sortable tables, TablePagination (1-based, 10 default), DateRangePicker (never `<input type="date">`), fmtMoney, chart-theme.ts, ShimmerBlock (not Loader2), editable-cell red-selection pattern
- `O:\RedTaxi\docs\backend-standards.md` — handler conventions, `Result<T>`, ResultExtensions `.ToActionResult()`/`.ToCommandResult()`
- All new v2 endpoints must return the envelope
- All new handlers must have `Log.ForContext("Feature", "HandlerName")` + Information on success + Warning on validation failures + Error on catches

---

## Staging testing

Staging API runs on port 5092 (NSSM service `redtaxi-api`) against local Postgres `redtaxi` DB with full production data.

- **Dev token (staging enabled):** `GET http://localhost:5092/dev/token?user=Peter`
- **AI agent tool secret:** `FOfhXhZklQTYSbrzzLRbgpPFl4ZIBbAA-kancF5ARY4NRBug0964pymUnhovmFyx` — header `X-AI-Agent-Secret`
- **Tenant org:** `org_3BfMRNcpn9933cL6snGXJ7k1PAN` (Ace Taxis Dorset)
- **Rebuild:** `cd src/backend && dotnet publish RedTaxi.API/RedTaxi.API.csproj -c Release -o O:/RedTaxi/staging/api-publish` (stop service first if file locks prevent)
- **Restart:** `powershell -Command "Restart-Service redtaxi-api"` — then `curl http://localhost:5092/health`
- **Admin v2 staging:** `https://staging-app.redtaxi.co.uk` (port 3100 locally)

### Test data — good high-confidence routes to develop against

| Route | Miles | Tariff 2 Price | Usage | Confidence |
|---|---:|---:|---:|---|
| DT10 1FW → SP8 4RE | 18.9 | £89 | 745 | high |
| SP7 9DQ → SP8 4RE | 17.8 | £84 | 728 | high |
| SP8 4QD → SP8 4UE | 4.1 | £23 | 353 | high |
| SP7 9NS → TW6 3XA (Heathrow T3) | 195.3 | £883 | 17 | medium |
| BA10 0JZ → TW6 2GA (Heathrow T2) | 204.9 | £926 | 11 | medium |
| BS48 3DY → SP7 9HQ (Bristol Airport) | 90.1 | £409 | 14 | medium |

### Data anomalies to surface in the UI

- Routes with `JourneyMiles=0` and `Tariff1Price=0` — enrichment didn't fill them in. ~several in airport pairs (e.g. SP7 9NS→TW6 2GA, SP7 0NH→TW6 1QG, BS48 3DY→SP7 9NS).
- SP8 5NX → TW6 1EW shows 205 min for 31.1 mi — median didn't catch this outlier. Investigate Stage 6's filter logic.

---

## Definition of Done

- [ ] New endpoints in IntelligenceController with Serilog logging + v2 envelope
- [ ] Snapshot tests for each new GET endpoint (follow `V2SnapshotTests.cs` pattern)
- [ ] Admin-v2 pages built with SortableTableHead + TablePagination + ShimmerBlock loading
- [ ] Nav items added to `src/lib/navigation.ts` under the Intelligence section
- [ ] Row click → detail view works
- [ ] Reload single + reload full cache buttons wired and confirmed to refresh the in-memory cache (check logs for `Intelligence search index loaded` after reload)
- [ ] Exclude/delete flow works and route is removed from cache on next lookup (test: quote SP7 9DQ→SP8 4RE, exclude it, re-quote and confirm fall-through to Google path)
- [ ] Data anomaly indicators visible (JourneyMiles=0 routes highlighted, outlier durations flagged)
- [ ] Page tested on staging-app.redtaxi.co.uk
- [ ] Feature branch merged to `dev` via PR (after PR #30 merges and this branch rebases)

---

## Proposed workflow

1. **Confirm branch:** `git branch --show-current` → `feature/intelligence-admin-pages`
2. **Read** the three CLAUDE.md files + `docs/backend-standards.md`
3. **Invoke the `api-shape-inspector` skill** on the existing `/intelligence/routes` endpoint to document its current shape, then design the new `/intelligence/route-cache` endpoint shape first
4. **Use the `superpowers:brainstorming` skill** for the page design (there are a few design choices to make — see Part 2/3)
5. **Use the `superpowers:writing-plans` skill** once brainstorming confirms scope
6. **Subagent-driven execution** per the plan (Peter's preference — see `feedback_use_subagents.md` memory)
7. Rebase onto `dev` once PR #30 merges
8. Open PR to `dev`

---

## Open questions to surface to Peter

1. Soft-delete (exclude flag) vs hard-delete for exclusions? Soft-delete is safer (pipeline regenerates hard-deleted rows).
2. Should `/intelligence/routes` (old) be deprecated/removed in this PR or left alongside?
3. Should the reload-single-route action rerun the full backfill for that pair's historical data, or just re-read the current aggregates?
4. Tariff 3 (Christmas) — is this an admin-managed date list or a code-defined pattern? Needs a decision before implementing the selection logic.
5. `ChargeFromBase` as company setting — is that in scope for this PR or a separate one?
