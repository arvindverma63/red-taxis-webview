# Frontend Map/Address Changes Required

These changes replace hardcoded geographic values with tenant config fetched from the API.
The backend work is complete — `GET /api/v2/settings/address` returns all 10 config keys.

## Config Keys Available from API

```json
{
  "MapDefaultCenterLat": "51.0397",
  "MapDefaultCenterLng": "-2.2863",
  "MapDefaultZoom": "13",
  "GooglePlacesCenterLat": "51.0478",
  "GooglePlacesCenterLng": "-2.2769",
  "GooglePlacesRadiusMeters": "32187",
  "GooglePlacesRegionCode": "GB",
  "BiasPostcodeOutward": "SP8,SP7",
  "PostcodeArea": "SP,BA,DT",
  "AddressLookupLimit": "20"
}
```

## Files to Update

### 1. Dispatch App — GoogleAutoComplete.jsx (2 files)

**Files:**
- `src/frontend/apps/dispatch/src/components/GoogleAutoComplete.jsx` (line 13-14)
- `src/frontend/apps/headless-dispatch/src/components/GoogleAutoComplete.jsx` (line 13-14)

**Current hardcodes:**
```js
const DEFAULT_LOCATION = { lat: 51.0388, lng: -2.2799 };
const DEFAULT_RADIUS = 10000;
```

**Replace with:** Fetch from settings API or pass as props from parent. Use `GooglePlacesCenterLat`, `GooglePlacesCenterLng`, `GooglePlacesRadiusMeters`.

### 2. Dispatch App — Map.jsx (2 files)

**Files:**
- `src/frontend/apps/dispatch/src/components/Map.jsx` (lines 16, 208, 246)
- `src/frontend/apps/headless-dispatch/src/components/Map.jsx` (lines 16, 208, 246)

**Current hardcodes:**
```js
// Line 16: default center
const center = { lat: 51.0397, lng: -2.2863 };
// Lines 208, 246: direction reset
map.setCenter({ lat: 51.0388, lng: -2.2799 });
```

**Replace with:** `MapDefaultCenterLat`, `MapDefaultCenterLng` from settings.

### 3. Admin v1 — Driver Tracking (legacy, low priority)

**File:** `src/frontend/apps/admin/src/pages/booking/tracking/driver-tracking.jsx` (lines 23-24, 49)

**Current hardcodes:**
```js
const [center, setCenter] = useState({ lat: 51.0397, lng: -2.2863 });
const [zoom, setZoom] = useState(14);
```

**Replace with:** `MapDefaultCenterLat`, `MapDefaultCenterLng`, `MapDefaultZoom`. Low priority since admin v1 is being replaced by admin-v2.

### 4. Admin v2 — Tracking Page

**File:** `src/frontend/apps/admin-v2/src/app/(dashboard)/tracking/page.tsx` (line 40)

**Current hardcode:**
```ts
const DORSET_CENTER = { lat: 50.94, lng: -2.15 };
```

**Replace with:** Fetch from `GET /api/v2/settings/address` and use `MapDefaultCenterLat`, `MapDefaultCenterLng`.

### 5. Admin v2 — Postcode Heatmap

**File:** `src/frontend/apps/admin-v2/src/components/admin/postcode-heatmap.tsx` (line 24)

**Current hardcode:**
```ts
const DORSET_CENTER = { lat: 50.94, lng: -2.15 };
```

**Replace with:** Same as tracking — `MapDefaultCenterLat`, `MapDefaultCenterLng` from settings.

## Approach

For admin-v2 files (items 4-5), create a `useAddressConfig()` hook in `src/frontend/apps/admin-v2/src/lib/hooks/` that:
- Fetches `GET /api/v2/settings/address` with TanStack Query
- Returns parsed config with defaults
- Cached for 5 minutes (config rarely changes)

For dispatch apps (items 1-2), the approach depends on the auth model — dispatch uses internal JWT, not Clerk. The settings API needs the tenant context from the JWT. Options:
- Pass config as props from the dispatch app's initial load
- Or fetch settings on app startup and store in context

Admin v1 (item 3) is low priority — skip unless specifically requested.
