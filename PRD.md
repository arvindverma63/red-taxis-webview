# Project Requirements & Progress Document (PRD)

This document serves as the high-level source of truth for the **Red Taxis Webview** project. It provides an immediate overview of the system architecture, code organization, integration points, completed work, and remaining tasks so that developers and AI agents can get up to speed without reading the entire repository.

---

## 🎯 Project Overview
Red Taxis Webview is a hybrid driver portal system consisting of:
1. **Flutter Mobile App (`src/mobile/driver_app`)**: A native application for drivers. It handles device services (location, auth, navigation, etc.) and uses standard Webviews for server-rendered or static components.
2. **Angular Webview App (`src/frontend/apps/driver-webview-app`)**: A web portal deployed to Vercel that is embedded directly into the native Flutter application's bottom navigation tabs.

---

## 🛠️ Technology Stack & Hosting
- **Native Shell**: Flutter (Dart) with Riverpod for state management, `webview_flutter` for rendering the web pages, `go_router` for reactive navigation, `dio` for network calls, and `flutter_secure_storage` for token persistence.
- **Web Portal**: Angular 21 with Material Components.
- **Hosting**:
  - Web Portal is hosted on Vercel at [https://red-taxis-webview.vercel.app](https://red-taxis-webview.vercel.app).
  - Configured in Flutter via [constants.dart](file:///d:/redtaxis/src/mobile/driver_app/lib/core/config/constants.dart).

---

## 📁 Repository Structure
- `src/mobile/driver_app/` - The Flutter mobile codebase.
  - `lib/core/config/constants.dart` - App configuration and webview base URLs.
  - `lib/core/location/` - Device location tracking services.
  - `lib/core/widgets/` - Shared UI widgets.
  - `lib/features/auth/` - Native authentication states and login screen.
  - `lib/features/dashboard/` - Native driver dashboard interface.
  - `lib/features/webview/` - Native Webview host screen.
- `src/frontend/apps/driver-webview-app/` - The Angular frontend codebase.
  - `src/app/bookings/` - Driver bookings dashboard view.
  - `src/app/profile/` - Profile and vehicle compliance details view.
  - `src/app/availability/` - Weekly shift planner view.
  - `src/app/upload/` - Document upload form and file picker view.
  - `src/app/login/` - Standalone webview login component (backup).
  - `src/app/guards/` - Router guard implementing parameter-aware token checks.
  - `src/app/services/` - `DriverService` providing staging API integration.
  - `src/app/app.routes.ts` - Routing configuration for web pages.

---

## 🔄 Integration Details (Flutter ↔ Webview)
The Flutter app embeds the Angular app via three sub-routes configured in `BottomNavigationBar`. To authorize the webviews, the Flutter shell appends the driver's JWT token directly to each URL parameter:
1. Bookings ➔ `/#/bookings?token=$token`
2. Profile ➔ `/#/profile?token=$token`
3. Availability ➔ `/#/availability?token=$token`

The Angular router guards and services parse the `token` parameter directly from both `window.location.search` and hash parameters `window.location.hash`, saving the active session to `localStorage` under `auth_token` for subsequent HTTP header authorization (`Authorization: Bearer <token>`).

---

## 📊 Development Status & Roadmap

### ✅ Completed Work
- [x] **Project Repository Setup**: Git repository initialized and linked to GitHub remote `https://github.com/developer1379/red-taxis-webview.git`.
- [x] **Angular Frontend Web App**: Fully refactored layout templates matching Figma specifications:
  - Removed duplicate double headings.
  - Ported booking filters to pill capsule chips layout.
  - Refactored weekly availability to a compact, single-card, row-by-day toggle view. Custom-styled the toggles (capsule buttons, no checkmark icons, solid brand colors on selected state).
  - Refactored profile header card, details listing, and added document status tag badges (Valid, Expiring Soon, Expired).
- [x] **Document Upload Component**: Integrated a dedicated document upload form at `/upload`. Supports drag & drop, file size checks, simulated progress bars, expiry inputs, and API uploads. Linked to profile compliance document list item clicks.
- [x] **Staging API Integration Service**: Built `DriverService` inside the Angular app mapping standard staging endpoints for profiles, completed jobs, today's jobs, future jobs, weekly availability slots, and compliance file uploads. Includes defensive envelope unwrapping (`Response.value || Response`) and real-time diagnostics banners inside the Profile view.
- [x] **CORS Proxy Routing Setup**: Configured a reverse proxy rewrite route in `vercel.json` (`/api/*` ➔ `https://staging-api.redtaxi.co.uk/api/*`) and a matching local development configuration `proxy.conf.json`. This completely bypasses all CORS (Cross-Origin Resource Sharing) restrictions, enabling hosted web pages to load live database data securely.
- [x] **Webview Hash Routing and Guard Fixes**: Configured hash routing (`withHashLocation()`) and updated the router guard to parse query tokens placed after the hash (e.g. `/#/bookings?token=XYZ`), preventing redirection loops back to webview logins.
- [x] **Native Flutter Login screen**: Designed a premium, light-themed native login page utilizing custom clippers (`HeaderClipper`), glowing branding badges, and gradient action buttons.
- [x] **Secure Storage Session Cache**: Integrated `FlutterSecureStorage` caching inside `AuthNotifier` to remember driver login states across restarts, alongside real JWT token fetching from the staging `/dev/token?user=<user>` API for testing and offline developer previews.
- [x] **Polished Native Dashboard**: Redesigned `dashboard_view.dart` to incorporate high-end widgets (Active/Offline duty toggles with pulsing status dots, Today's earnings metric columns, simplified dev simulation decks, and recent completed trips rows). Wired `EarningsNotifier` to fetch real live completed jobs from the staging database via `GET /api/DriverApp/CompletedJobs` dynamically using secure cached JWT tokens, falling back to static mock data if the API returns empty list or fails.
- [x] **Native Sign Out Actions**: Embedded logout triggers in the native dashboard App bar that clear cached secure credentials and reset routing guards.
- [x] **Real Location Tracking**: Connected location service `lib/core/location` to automatically stream live GPS coordinates (`POST /api/DriverApp/UpdateGPS`) at 5-second intervals when the driver is online.
- [x] **Online/Offline Shift Management**: Connected dashboard online/offline duty status toggles to notify the database (`GET /api/DriverApp/DriverShift`).
- [x] **Active Trip Lifecycle Integration**: Connected Riverpod trip notifier to poll live job offers (`GET /api/DriverApp/GetJobOffers`) and call corresponding backend routes (`JobOfferReply`, `Arrived`, `JobStatusReply`, `CompleteJob`) for accepting, declining, arriving, starting, and completing jobs.
- [x] **Webview Profile Integration**: Corrected key mappings in `ProfileComponent` (supporting both camelCase and staging backend's lowercase keys `fullname`, `telephone`, `vehicleReg`, etc.) to dynamically load real profile data in the webview. Removed fallback defaults to mock data (`Mercedes-Benz E-Class`, `LD67 WRX`) when successful API queries return empty/blank fields.
- [x] **Webview Bookings API Integration**: Updated `BookingsComponent` to properly overwrite mock static lists when API calls succeed but return empty arrays (`[]`), ensuring the real database state is rendered correctly.
- [x] **Webview Token Propagation didUpdateWidget Fix**: Implemented `didUpdateWidget` in the Flutter webview widget to ensure the WebViewController reloads and propagates the newly acquired token to the underlying Angular shell immediately upon successful authentication. Formatted URLs to pass query parameters before the hash fragment (e.g. `/?token=...#/profile`), ensuring reliable token extraction by browser `URLSearchParams` on SPA routings. Prioritized URL query-parameter tokens over stale `localStorage` cache values in the Angular guards/services to guarantee immediate profile refreshes when signing in.
- [x] **Webview Zoneless Change Detection Fix**: Added manual `ChangeDetectorRef.detectChanges()` triggers inside async subscriptions across the webview components (`ProfileComponent`, `BookingsComponent`, and `AvailabilityComponent`). This forces UI rendering in zoneless/de-facto hybrid environments where standard Zone.js change detection loops do not automatically fire on async callbacks.
- [x] **Webview Route Pollution Redirection Fix**: Resolved the race-condition bug where the Profile or Availability webview tabs would dynamically rewrite themselves to show the Bookings component. Implemented dynamic `returnUrl` query parameter capturing in `authGuard` and route-parameterized redirection in the webview `LoginComponent` to guarantee webview tabs always restore their originally intended routes upon token verification.
- [x] **Webview Platform Registry Assertion Fix**: Wrapped webview initialization with `kIsWeb` check in the Flutter screen widget to bypass platform interface registration crashes on the Web target, showing a clean explanation banner in development browser tabs.
- [x] **Network Logging Interceptors**: Configured Dio `LogInterceptor` across all mobile HTTP clients and implemented RxJS `tap` console log pipelines for all Angular webview requests, printing formatted requests, payload bodies, and error diagnostics directly to development consoles.
- [x] **Vercel Reverse Proxy Rewrites**: Fixed `vercel.json` rewrites to proxy all webview `/api/*` network requests directly to the backend staging API (`https://staging-api.redtaxi.co.uk`).
- [x] **Webview Availability API Integration**: Connected the availability portal to dynamically load, save, and clear weekly driver shifts from the database via `GET /api/DriverApp/Availabilities`, `POST /api/DriverApp/SetAvailability`, and `GET /api/DriverApp/DeleteAvailability`. Refactored the UI with a premium light-themed card layout matching other screens, and implemented calendar week navigation controls (including a calendar date picker pop-up) to support flexible scheduling. Solved the native Android WebView NullPointerException crash by replacing HTML5 time input pickers with custom styled hour/minute select dropdowns. Implemented timezone-safe local date formatting and parsing, aligned select dropdown hour/minute value options with robust leading-zero string normalization, and bound [selected] states directly on child <option> elements to ensure the selected shift times are correctly displayed on reload. Added verbose JSON-stringified logging and explicit overlap/save error snackbar notifications to easily debug and diagnose backend conflicts. Removed the redundant webview top header since the native Flutter app bar already contains a header, and replaced the status toggles with custom animated sliding capsule switches to elevate design and animation premium feel.
- [x] **Webview Driver Profile & Compliance Uploads**: Redesigned the driver profile and compliance document upload portals to match the staging API schema. Integrated JWT base64 decoding on the client-side to dynamically resolve the driver's database `UserId` from the session token. Connected the compliance document section to `/api/AdminUI/GetDriverExpirys` to fetch and format dynamic expiration dates and statuses (`Valid`, `Expiring Soon`, `Expired`, `Missing`) for all 9 core backend document types. Enabled the profile header to dynamically color itself and its avatar badge based on the driver's registered `ColorCode` in the database. Connected the file upload zone to `/api/DriverApp/UploadDocument` via a `multipart/form-data` request with progress reporting (`HttpEventType.UploadProgress`), allowing drivers to submit scanned files with real-time progress bars.

### ⏳ Remaining Work / Roadmap
- [ ] **Native Back Button Handling**: Capture back navigation inside Webviews so users don't exit the app accidentally.
- [ ] **Live Trip State Updates**: Connect Riverpod state to real-time WebSockets (e.g., Pusher) for receiving job offers instead of mock triggers.
