# Multi-Tenant Authentication & Dynamic Tenant Branding Specification

**Document Version:** 1.0.0  
**Target Audience:** Backend API Team, Mobile (Flutter) Engineering, Web (Angular) Engineering  
**System Scope:** Red Taxis / First Taxis Hybrid Driver Portal & Staging/Production Backend API  
**Status:** Approved Architecture Specification  

---

## 1. Executive Summary

### 1.1 The Challenge
Currently, the mobile client ([`constants.dart`](file:///d:/redtaxis/src/mobile/driver_app/lib/core/config/constants.dart)) and webview frontend ([`driver.service.ts`](file:///d:/redtaxis/src/frontend/apps/driver-webview-app/src/app/services/driver.service.ts)) hardcode tenant identification:
```typescript
// Hardcoded static tenant definition
readonly defaultTenantId = 'org_ace_taxis';
```
This hardcoded configuration prevents true multi-tenant deployment. As fleet operators and taxi companies onboard, maintaining separate app binaries or manual config branches creates operational friction and deployment overhead. Furthermore, branding (app logo, company title, primary theme colors, hero gradients, and receipts) is statically compiled rather than dynamically resolved.

### 1.2 The Solution
1. **One-Time Onboarding & Local Config Persistence**:
   - On first launch (or when no tenant is configured), the app prompts the driver for their **Tenant ID** and **Tenant Key** (or auto-configures via onboarding QR code scan).
   - Once validated, these credentials and the downloaded branding kit are saved permanently in local secure configuration (`FlutterSecureStorage`).
2. **Simplified Login & Logout Experience**:
   - Once a tenant is configured locally, subsequent app launches and post-logout screens **only display Username and Password**.
   - The screen is pre-rendered with the saved tenant's branding (logo, colors, company name).
   - The saved `tenantId` and `tenantKey` are automatically attached to the login request payload under the hood.
3. **Change Fleet / Tenant from Settings**:
   - If a driver switches fleets or receives a new access key, they can view, update, or switch their Tenant ID and Tenant Key directly from the **Settings** screen (`settings_view.dart`).
4. **Dynamic White-Label Reskinning**:
   - The backend returns the tenant's complete branding kit (logos, color codes, gradient stops, typography hints, and support details). Both the native Flutter shell and the embedded Angular Webviews adapt their themes, logos, and layouts on the fly based on the authenticated tenant.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            DRIVER MOBILE APP                                 │
│                                                                              │
│  [First Launch Only]               [Subsequent Logins & Post-Logout]         │
│  ┌───────────────────────────┐     ┌──────────────────────────────────────┐  │
│  │ Tenant ID:  org_first...  │ ──► │ Active Fleet: FIRST TAXIS [Switch]   │  │
│  │ Tenant Key: tk_live_...   │     │ Username:     driver01               │  │
│  └───────────────────────────┘     │ Password:     •••••••••••••          │  │
│   (Saved in Local Secure Config)   └───────────────────┬──────────────────┘  │
└────────────────────────────────────────────────────────┼─────────────────────┘
                                                         │ POST /api/UserProfile/Login
                                                         │ (tenantId & tenantKey auto-injected)
                                                         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                            BACKEND API GATEWAY                               │
│  1. Validates Tenant ID & Tenant Key against Tenant Registry                 │
│  2. Authenticates Driver Username & Password in Tenant Database Scope        │
│  3. Issues JWT Token + Serializes Tenant Branding Object                     │
└──────────────────────────────────────┬───────────────────────────────────────┘
                                       │ Response: { token, driver, tenantBranding }
                                       ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                    DYNAMIC CLIENT RESKINNING ENGINE                          │
│  • Flutter: Updates Material 3 ColorScheme, AppBar, Drawer, and Logos        │
│  • Webview: Injects CSS Custom Properties (--primary-color, --logo-url, etc.)│
│  • Settings: Driver can view or change Tenant ID & Key at any time           │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. API Contract & Endpoint Specifications

### 2.1 Primary Login & Tenant Authentication

* **Route:** `POST /api/UserProfile/Login`
* **Content-Type:** `application/json`
* **Accept:** `application/json`

#### Request Payload
```json
{
  "tenantId": "org_first_taxis",
  "tenantKey": "tk_live_8f93c72b10a94e82b7",
  "username": "driver101",
  "password": "Password123!"
}
```

| Field | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `tenantId` | `string` | **Yes** | Unique slug or identifier of the fleet organization (e.g., `org_first_taxis`, `org_ace_taxis`). |
| `tenantKey` | `string` | **Yes** | Public/Client security key verifying that the request originates from an authorized device for this fleet. |
| `username` | `string` | **Yes** | Driver username, badge ID, or email address. |
| `password` | `string` | **Yes** | Driver account password. |

---

#### Success Response (`200 OK`)
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "d820f12b-34ef-4b2a-89a1-02a9b31d09e8",
  "expiresIn": 86400,
  "userId": 135822,
  "driver": {
    "id": 135822,
    "fullname": "David Miller",
    "telephone": "+447700900123",
    "email": "david.miller@example.co.uk",
    "badgeNumber": "B-4921",
    "vehicleReg": "LD67 WRX",
    "vehicleModel": "Toyota Prius Hybrid (White)",
    "colorCode": "#CD1A21"
  },
  "tenant": {
    "id": "org_first_taxis",
    "name": "First Taxis",
    "legalName": "First Taxis Group Ltd",
    "slug": "first-taxis",
    "status": "Active",
    "branding": {
      "logos": {
        "lightUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/logo-light.png",
        "darkUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/logo-dark.png",
        "symbolUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/symbol.png",
        "faviconUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/favicon.ico"
      },
      "colors": {
        "primary": "#CD1A21",
        "primaryDark": "#9E0E14",
        "primaryLight": "#FF5252",
        "accent": "#F59E0B",
        "gradientStart": "#CD1A21",
        "gradientMid": "#9E0E14",
        "gradientEnd": "#6B0509",
        "light": {
          "background": "#F4F6F9",
          "surface": "#FFFFFF",
          "textPrimary": "#0F172A",
          "textSecondary": "#64748B",
          "border": "#E2E8F0"
        },
        "dark": {
          "background": "#0F172A",
          "surface": "#1E293B",
          "textPrimary": "#F8FAFC",
          "textSecondary": "#94A3B8",
          "border": "#334155"
        }
      },
      "typography": {
        "fontFamily": "Roboto, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        "headingLetterSpacing": "2.5px"
      },
      "support": {
        "dispatchPhone": "+441234567890",
        "supportEmail": "drivers@firsttaxis.co.uk",
        "termsUrl": "https://firsttaxis.co.uk/driver-terms",
        "privacyUrl": "https://firsttaxis.co.uk/privacy"
      }
    },
    "features": {
      "fcmPushEnabled": true,
      "rankPickupEnabled": true,
      "expensesModuleEnabled": true,
      "weeklyAvailabilityEnabled": true,
      "statementsDownloadEnabled": true,
      "documentUploadValidation": true
    }
  }
}
```

---

#### Error Responses

##### 1. Invalid Tenant Key or Inactive Fleet (`403 Forbidden`)
Returned when the `tenantId` is recognized but the `tenantKey` does not match the organization's active access key.
```json
{
  "statusCode": 403,
  "errorCode": "TENANT_KEY_INVALID",
  "message": "The provided Tenant Key is invalid or expired for organization 'org_first_taxis'."
}
```

##### 2. Tenant Not Found (`404 Not Found`)
Returned when no organization matches the supplied `tenantId`.
```json
{
  "statusCode": 404,
  "errorCode": "TENANT_NOT_FOUND",
  "message": "Organization identifier 'org_unknown' was not found."
}
```

##### 3. Invalid Driver Credentials (`401 Unauthorized`)
Returned when the tenant is valid, but the driver username or password is incorrect.
```json
{
  "statusCode": 401,
  "errorCode": "AUTH_INVALID_CREDENTIALS",
  "message": "Incorrect driver username or password for this fleet."
}
```

##### 4. Missing Parameters (`400 Bad Request`)
```json
{
  "statusCode": 400,
  "errorCode": "VALIDATION_FAILED",
  "message": "Validation failed",
  "errors": {
    "tenantId": ["Tenant ID is required."],
    "tenantKey": ["Tenant Key is required."],
    "username": ["Driver username is required."],
    "password": ["Password is required."]
  }
}
```

---

### 2.2 Optional Pre-Validation Endpoint: Tenant Info Resolution

To optimize user experience, the mobile app can resolve tenant branding **before** the driver enters their username and password (e.g., when entering or scanning the Tenant ID & Key, or when loading the app with cached tenant data).

* **Route:** `POST /api/Tenant/Resolve` (or `GET /api/Tenant/Info?tenantId=...&tenantKey=...`)
* **Purpose:** Validates the tenant credentials and retrieves branding configuration so the login screen immediately displays the correct company logo, colors, and title.

#### Request
```json
{
  "tenantId": "org_first_taxis",
  "tenantKey": "tk_live_8f93c72b10a94e82b7"
}
```

#### Success Response (`200 OK`)
```json
{
  "tenantId": "org_first_taxis",
  "name": "First Taxis",
  "status": "Active",
  "branding": {
    "logos": {
      "lightUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/logo-light.png",
      "darkUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/logo-dark.png",
      "symbolUrl": "https://cdn.redtaxi.co.uk/tenants/first-taxis/symbol.png"
    },
    "colors": {
      "primary": "#CD1A21",
      "primaryDark": "#9E0E14",
      "primaryLight": "#FF5252",
      "accent": "#F59E0B",
      "gradientStart": "#CD1A21",
      "gradientMid": "#9E0E14",
      "gradientEnd": "#6B0509"
    }
  }
}
```

---

## 3. Database & Entity Schema (Backend Implementation)

### 3.1 `Tenants` Table
```sql
CREATE TABLE Tenants (
    TenantId VARCHAR(64) PRIMARY KEY,               -- e.g. 'org_first_taxis'
    TenantKeyHash VARCHAR(256) NOT NULL,            -- SHA-256 / PBKDF2 hash of tenant access key
    TenantKeyHint VARCHAR(16) NOT NULL,             -- e.g. 'tk_live_...e82b'
    DisplayName VARCHAR(128) NOT NULL,              -- e.g. 'First Taxis'
    LegalName VARCHAR(256) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

### 3.2 `TenantBranding` Table
```sql
CREATE TABLE TenantBranding (
    BrandingId INT IDENTITY(1,1) PRIMARY KEY,
    TenantId VARCHAR(64) NOT NULL UNIQUE FOREIGN KEY REFERENCES Tenants(TenantId),
    LogoLightUrl VARCHAR(512) NOT NULL,
    LogoDarkUrl VARCHAR(512) NOT NULL,
    SymbolUrl VARCHAR(512) NULL,
    FaviconUrl VARCHAR(512) NULL,
    PrimaryColor VARCHAR(9) NOT NULL DEFAULT '#CD1A21',      -- Hex color code
    PrimaryDarkColor VARCHAR(9) NOT NULL DEFAULT '#9E0E14',
    PrimaryLightColor VARCHAR(9) NOT NULL DEFAULT '#FF5252',
    AccentColor VARCHAR(9) NOT NULL DEFAULT '#F59E0B',
    GradientStart VARCHAR(9) NOT NULL DEFAULT '#CD1A21',
    GradientMid VARCHAR(9) NOT NULL DEFAULT '#9E0E14',
    GradientEnd VARCHAR(9) NOT NULL DEFAULT '#6B0509',
    DispatchPhone VARCHAR(32) NULL,
    SupportEmail VARCHAR(128) NULL,
    TermsUrl VARCHAR(512) NULL,
    PrivacyUrl VARCHAR(512) NULL,
    FeaturesJson NVARCHAR(MAX) NULL                          -- JSON string of enabled modules
);
```

---

## 4. Client-Side Dynamic Implementation

### 4.1 Flutter Mobile Shell (`src/mobile/driver_app`)

#### 1. Dual-State Login Screen Lifecycle

##### State A: First Launch / Unconfigured State (One-Time Setup)
If no `tenant_id` is found in local secure storage:
* The app prompts for **Tenant ID** and **Tenant Key** (with an option to scan an onboarding QR code).
* Once the driver enters the tenant details, the app calls `POST /api/Tenant/Resolve` to validate the fleet.
* Upon validation:
  1. `tenant_id` and `tenant_key` are saved to `FlutterSecureStorage`.
  2. `tenant_branding` (logos, colors, title) is cached locally.
  3. `tenantThemeProvider` immediately applies the tenant's visual theme.
  4. The form transitions directly to State B.

##### State B: Configured State (Standard Login & Post-Logout)
Once a tenant is saved in local secure storage (and anytime the driver logs out):
* The login screen displays **only two fields**:
  1. **Driver Username / ID**
  2. **Password**
* The header dynamically renders the configured tenant's logo, brand colors, and company name.
* A subtle footer chip is displayed:  
  `🏢 Fleet: First Taxis (org_first_taxis) • [Switch Fleet]`  
  *(Tapping `[Switch Fleet]` allows the driver to re-open the Tenant Setup dialog if they need to change fleets prior to logging in).*
* When the driver submits the form, `auth.dart` retrieves the stored `tenant_id` and `tenant_key` from secure storage and sends them along with the username and password in `POST /api/UserProfile/Login`.

#### 2. Settings Screen Fleet Management (`settings_view.dart`)
Drivers can view or update their tenant credentials at any time while logged in:
* Inside [`settings_view.dart`](file:///d:/redtaxis/src/mobile/driver_app/lib/features/settings/presentation/settings_view.dart), a dedicated **"Fleet & Organization"** card displays:
  - Active Fleet Name and Logo thumbnail.
  - Active Tenant ID (e.g., `org_first_taxis`).
  - Active Tenant Key hint (e.g., `tk_live_••••••••e82b` with a green `Verified` badge).
* **"Change Fleet / Update Key" Action**:
  - Tapping this button opens a bottom sheet with Tenant ID and Tenant Key fields (and QR scan support).
  - Validates the new credentials against `POST /api/Tenant/Resolve`.
  - On confirmation:
    1. Updates `tenant_id`, `tenant_key`, and `tenant_branding` in `FlutterSecureStorage`.
    2. Instantly updates the theme and logos via `tenantThemeProvider`.
    3. Clears the previous session token and returns the driver to the login screen with the new fleet branding and a confirmation banner: *"Switched to [Fleet Name]. Please sign in with your account for this fleet."*

#### 3. Persistent Storage Schema (`FlutterSecureStorage`)
The following keys are persisted across app sessions:
* `tenant_id`: The organization identifier string (e.g. `'org_first_taxis'`).
* `tenant_key`: The client/fleet API security key.
* `tenant_branding`: JSON string containing downloaded logo URLs, color palettes, and organization metadata.
* `auth_token`: Active driver JWT session token.
* `auth_user_id`: Driver database ID.

When the app launches, `SplashScreen` reads `tenant_branding` synchronously from secure storage. If present, the splash screen and login screen render with the tenant's logo and color palette with **zero visual flicker**.

#### 4. Dynamic Theme Provider
In [`theme.dart`](file:///d:/redtaxis/src/mobile/driver_app/lib/core/theme/theme.dart), `AppTheme` is refactored from static `const Color` to a dynamic Riverpod `tenantThemeProvider`:
```dart
class TenantBranding {
  final String name;
  final String logoLightUrl;
  final String logoDarkUrl;
  final Color primary;
  final Color primaryDark;
  final Color gradientStart;
  final Color gradientMid;
  final Color gradientEnd;
  // ...
  
  ThemeData toThemeData(Brightness brightness) {
    // Generates dynamic ThemeData using primary and primaryDark colors
  }
}
```

#### 5. Propagating Tenant & Theme to WebViews
When opening an Angular Webview tab, the Flutter host passes the dynamic tenant configuration:
```dart
final webviewUrl = '$baseUrl/?token=$token'
    '&tenantId=$tenantId'
    '&primary=${branding.primaryHex}'
    '&primaryDark=${branding.primaryDarkHex}'
    '&logo=${Uri.encodeComponent(branding.logoLightUrl)}'
    '#/bookings';
```

---

### 4.2 Angular Webview Application (`src/frontend/apps/driver-webview-app`)

#### 1. Dynamic CSS Variables Override
In [`styles.css`](file:///d:/redtaxis/src/frontend/apps/driver-webview-app/src/styles.css) and root component `App`:
```typescript
function applyTenantBranding(branding: TenantBranding) {
  const root = document.documentElement;
  root.style.setProperty('--primary-color', branding.colors.primary);
  root.style.setProperty('--primary-dark', branding.colors.primaryDark);
  root.style.setProperty('--primary-light', branding.colors.primaryLight);
  root.style.setProperty('--accent-color', branding.colors.accent);
  
  // Update browser document title
  document.title = `${branding.name} Driver Portal`;
}
```

#### 2. Dynamic Logo Injection
Replace hardcoded taxi glyphs or static SVGs with an image element bound to `tenant.branding.logos.lightUrl` with an SVG fallback:
```html
<div class="logo-container">
  <img 
    *ngIf="tenantLogo" 
    [src]="tenantLogo" 
    [alt]="tenantName" 
    class="tenant-brand-logo"
  />
  <span *ngIf="!tenantLogo" class="material-symbols-outlined">local_taxi</span>
</div>
<h1 class="brand-title">{{ tenantName }}</h1>
```

---

## 5. Security & Migration Strategy

### 5.1 Backwards Compatibility
To ensure existing client builds and test scripts do not break during rollout:
* If a login request arrives **without** `tenantKey`, the backend can check if `tenantId == 'org_ace_taxis'` or a staging default, allowing backward-compatible access for legacy releases.
* Once all clients update to Version 2.0+, `tenantKey` becomes strictly enforced.

### 5.2 Tenant Key Protection
* `TenantKey` should never be exposed in public source control or static files.
* Drivers receive their `TenantId` and `TenantKey` from their fleet administrator via onboarding SMS, email, or an activation QR code.
* The mobile app allows scanning an onboarding QR code:
  ```json
  {
    "tenantId": "org_first_taxis",
    "tenantKey": "tk_live_8f93c72b10a94e82b7"
  }
  ```
  This auto-populates the Tenant ID and Key fields on the login screen, eliminating manual typing errors.

---

## 6. Implementation Checklist

- [ ] **Backend Phase 1**: Create `Tenants` and `TenantBranding` database tables and seed with `org_first_taxis` and `org_ace_taxis`.
- [ ] **Backend Phase 2**: Update `POST /api/UserProfile/Login` to accept `tenantId` and `tenantKey`, validate against `Tenants` table, and return the `tenant` branding object.
- [ ] **Backend Phase 3**: Implement `POST /api/Tenant/Resolve` (or `GET /api/Tenant/Info`) for pre-login branding resolution.
- [ ] **Mobile Phase 1 (Initial Setup & Clean Login UX)**:
  - Implement dual-state [`login_screen.dart`](file:///d:/redtaxis/src/mobile/driver_app/lib/features/auth/presentation/login_screen.dart): State A prompts for Tenant ID & Key on initial launch; State B displays only Username and Password once saved.
  - Automatically attach stored `tenant_id` and `tenant_key` from `FlutterSecureStorage` on every login attempt.
  - Add `[Switch Fleet]` quick action button on the login screen to allow resetting or changing fleet before logging in.
- [ ] **Mobile Phase 2 (Settings Fleet Management)**:
  - Add **"Fleet & Organization"** section inside [`settings_view.dart`](file:///d:/redtaxis/src/mobile/driver_app/lib/features/settings/presentation/settings_view.dart).
  - Implement "Change Fleet / Update Key" modal to allow drivers to switch tenants or enter updated keys without reinstalling the app.
- [ ] **Mobile Phase 3 (Dynamic Reskinning)**:
  - Implement `TenantThemeProvider` and store `tenant_branding` in `FlutterSecureStorage`.
  - Pass dynamic tenant branding to embedded WebViews via URL query parameters.
- [ ] **Frontend Webview**: Implement dynamic CSS variable injection in Angular root, applying tenant colors and logos to all views.

