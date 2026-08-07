# Intelligence Admin UI — Design Spec

## Context

The intelligence pipeline produces 4,579 canonical locations, 2,771 aliases, 10,783 routes,
and 3,543 STT bias terms. Tenant operators need to view, search, edit, and manage this data
to improve AI agent accuracy. Currently, all management is via API endpoints only.

## Pages

### 1. `/intelligence/locations` — Canonical Locations

**Table columns:** Name, Spoken Name, Postcode, Outward Code, Type, Frequency, Last Seen
**Features:**
- Search box: filters by canonical name, alias text, postcode (server-side)
- Type filter dropdown: all location types
- Postcode outward filter: multi-select chips
- Inline edit: spoken name, location type (click cell to edit, save on blur/enter)
- Expand row: shows aliases for that canonical
- Delete: confirm dialog, cascades to aliases
- Merge: select 2+ rows, merge into highest-frequency canonical
- Pagination: server-side (50 per page default)

### 2. `/intelligence/routes` — Popular Routes

**Table columns:** Pickup, Destination, Usage Count, Avg Fare, Last Used
**Features:**
- Search by pickup or destination name
- Sort by usage count (default), fare, recency
- Pagination: server-side

### 3. `/intelligence/hotlist` — POI Hot List

**Table columns:** Rank, POI Name, Shorthand Keys (comma-separated), Postcode, Frequency, Type
**Features:**
- Read-only view of what the in-memory hot list contains
- Coverage stat: X% of bookings handled
- Auto-generated, no manual editing

### 4. `/intelligence/pipeline` — Pipeline Controls

**Stats cards:** Canonical count, Alias count, Route count, STT terms, Hot list keys
**Actions:** Run Backfill, Run Incremental, Run with Legacy MSSQL, Run Export
**Status:** Last run timestamp, success/failure indicator

## Backend Endpoints (new)

All under `api/v2/intelligence/`:

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/locations` | Paginated list with search, type filter, postcode filter |
| GET | `/locations/{id}` | Single canonical with aliases |
| PUT | `/locations/{id}` | Update spoken name, location type |
| DELETE | `/locations/{id}` | Delete canonical (cascades aliases) |
| POST | `/locations/merge` | Merge multiple canonical IDs into one |
| GET | `/routes` | Paginated popular routes with search |
| GET | `/hotlist` | Current hot list dictionary dump |
| GET | `/stats` | Pipeline statistics |

## Tech Stack

- Frontend: Next.js 16 + React 19 + shadcn/ui + TanStack Query (matches admin-v2)
- Backend: MediatR handlers + v2 controller endpoints
- Navigation: New "Intelligence" section in sidebar with Brain icon
