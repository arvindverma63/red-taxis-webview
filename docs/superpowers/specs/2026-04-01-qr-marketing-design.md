# QR Code Marketing Feature — Design Spec

**Date:** 2026-04-01
**Status:** IMPLEMENTED
**Author:** Claude + Peter

> **Implementation notes:** Backend + frontend complete. QR Scan Report page removed —
> scan analytics integrated directly into the QR Codes management page. Old `/reports/qr-scans`
> route deleted. QrCodes table created in Postgres. All endpoints tested and working.

---

## Problem

The v1 QR system is basic — hardcoded redirect to acetaxisdorset.co.uk, simple location logging, no QR code creation UI. Operators have to generate QR codes externally and manually track where they're placed. The reporting page exists but lives under Financial Reports which doesn't make sense.

## Design

### 1. Navigation

New top-level **MARKETING** sidebar section:

```
MARKETING
  ├─ QR Codes        /marketing/qr-codes     (manage + create + download)
  └─ QR Scan Report  /marketing/qr-scans     (analytics — moved from Financial)
```

Remove QR Code Adverts from the Financial Reports nav section.

### 2. Page: QR Codes (`/marketing/qr-codes`)

#### Layout (top to bottom)

1. **Page header** — "QR Codes" with eyebrow "MARKETING" + "Create QR Code" button
2. **Stat cards** (3) — Total QR Codes, Total Scans (all time), Most Scanned Location
3. **QR codes table** — all created codes

#### Stat Cards

| Label | Value | Icon |
|-------|-------|------|
| Total QR Codes | count of codes | QrCode |
| Total Scans | sum of all scans | ScanLine |
| Most Scanned | location name with highest scans | Trophy |

#### Table Columns

| Column | Content |
|--------|---------|
| Location | Label e.g. "ASDA Gillingham" |
| Destination | URL (truncated, hover for full) |
| Short Link | `api.redtaxi.co.uk/qr/{code}` — click to copy |
| Scans | Total scan count |
| First Scan | Date of first scan (or "–" if never scanned) |
| Last Scan | Date of most recent scan (or "–") |
| Created | Date created |
| Actions | Download (branded PNG) / Delete (with ConfirmDialog) |

Sortable columns. Default sort: created date descending. Pagination: 10 rows.

#### Create QR Code Dialog

Triggered by "Create QR Code" button in page header. Dialog contains:

- **Location** — text input, required, placeholder "e.g. ASDA Gillingham, Vehicle #4 rear window"
- **Destination URL** — URL input, required, placeholder "https://mybusiness.co.uk/book"
- **Live Preview** — branded QR code preview updates as user types, showing:
  - White card with rounded corners
  - QR code (dark modules on white) encoding `{API_URL}/qr/{shortCode}`
  - Red Taxi logo overlaid in QR centre
  - Tenant name below QR
  - Location label at bottom
  - "Scan to book" call-to-action
- **Create & Download** button — saves to DB, downloads branded PNG, closes dialog, refreshes table

#### QR Code Generation

Client-side using `qr-code-styling` npm package:
- Generates styled QR with logo overlay
- Branded template rendered on HTML Canvas
- Exported as PNG for download
- The QR encodes: `{NEXT_PUBLIC_API_URL}/qr/{shortCode}`

### 3. Page: QR Scan Report (`/marketing/qr-scans`)

Move the existing QR Code Adverts page from `/reports/qr-scans` to `/marketing/qr-scans`. Same content — stat card, bar chart, data table with Location, Scan Count, First Scan, Last Scan.

Add redirect from old route to new route for bookmarks.

### 4. Backend

#### New Entity: `QrCode`

```csharp
public class QrCode
{
    public int Id { get; set; }
    public string Location { get; set; }        // label for where QR is placed
    public string DestinationUrl { get; set; }   // where scans redirect to
    public string ShortCode { get; set; }         // 6-char unique code
    public string TenantId { get; set; }          // multi-tenant
    public DateTime CreatedAt { get; set; }
}
```

Register in `RedTaxiDbContext`: `public DbSet<QrCode> QrCodes { get; set; }`

EF migration to create the table. Index on `ShortCode` (unique).

#### New Endpoints

**Marketing Controller** (`/api/v2/marketing/...`):

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/api/v2/marketing/qr-codes` | Authorize | Create a new QR code |
| GET | `/api/v2/marketing/qr-codes` | Authorize | List all QR codes with scan counts |
| DELETE | `/api/v2/marketing/qr-codes/{id}` | Authorize | Delete a QR code |

**Redirect Controller** (root level, no `/api/` prefix):

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| GET | `/qr/{shortCode}` | **None** (public) | Record scan + 302 redirect |

#### Create QR Code Flow

1. Frontend sends `POST /api/v2/marketing/qr-codes` with `{ location, destinationUrl }`
2. Backend generates 6-char shortCode (alphanumeric, check uniqueness)
3. Saves `QrCode` entity
4. Returns `{ success: true, data: { id, shortCode, location, destinationUrl, createdAt } }`
5. Frontend uses the shortCode to generate the QR image client-side

#### List QR Codes Flow

1. Frontend calls `GET /api/v2/marketing/qr-codes`
2. Backend queries `QrCodes` table joined with `QRCodeClicks` (grouped by Location) to get scan counts
3. Returns array of `{ id, location, destinationUrl, shortCode, createdAt, scanCount, firstScan, lastScan }`

#### Redirect Flow

1. User scans QR → browser navigates to `api.redtaxi.co.uk/qr/aBc123`
2. `GET /qr/aBc123` hits the redirect controller
3. Controller looks up QrCode by shortCode
4. If not found → 404 page
5. If found → insert `QRCodeClick(location: qrCode.Location, timestamp: now)` into existing QRCodeClicks table
6. Return `HTTP 302 Redirect` to `qrCode.DestinationUrl`

This reuses the existing `QRCodeClicks` table so all existing reporting queries (GetQRScans) continue to work without changes.

#### Short Code Generation

```csharp
const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
// Generate 6-char code, retry if collision (check DB uniqueness)
```

### 5. Frontend Hooks

- `useQrCodes()` — GET list with scan counts
- `useCreateQrCode()` — POST mutation
- `useDeleteQrCode()` — DELETE mutation

### 6. Dependencies

New npm package: `qr-code-styling` — for branded QR code generation with logo overlay.

### 7. Files to Create/Modify

**Backend (new):**
- `RedTaxi.Data/Models/QrCode.cs` — entity
- `RedTaxi.Data/Migrations/...` — EF migration
- `RedTaxi.Application/Features/Marketing/CreateQrCode.cs` — handler
- `RedTaxi.Application/Features/Marketing/GetQrCodes.cs` — handler
- `RedTaxi.Application/Features/Marketing/DeleteQrCode.cs` — handler
- `RedTaxi.API/Controllers/V2/MarketingController.cs` — CRUD endpoints
- `RedTaxi.API/Controllers/QrRedirectController.cs` — public redirect endpoint

**Backend (modify):**
- `RedTaxi.Data/RedTaxiDbContext.cs` — add DbSet<QrCode>

**Frontend (new):**
- `src/app/(dashboard)/marketing/qr-codes/page.tsx` — main page
- `src/app/(dashboard)/marketing/qr-scans/page.tsx` — moved report page
- `src/lib/hooks/use-qr-codes.ts` — hooks
- `src/components/admin/qr-code-preview.tsx` — branded QR preview component

**Frontend (modify):**
- `src/lib/navigation.ts` — add Marketing section, remove QR from Financial
- `src/components/admin/sidebar-nav-item.tsx` — update COMPLETED_ROUTES

### 8. Constraints

- ShortCode must be unique per tenant
- Redirect endpoint must be fast (no auth, minimal DB work)
- QR code PNG download must work offline (generated client-side, not server-rendered)
- Delete QR code should NOT delete historical scan data (QRCodeClicks remain)
- Existing `/qrcode/{location}` v1 endpoint continues to work (don't break it)
- Follow all CLAUDE.md rules: SortableTableHead, TablePagination, fmtMoney where applicable, ConfirmDialog for delete, DateRangePicker not needed (no date filtering on QR codes list)
