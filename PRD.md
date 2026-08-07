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
- [x] **Staging API Integration Service**: Built `DriverService` inside the Angular app mapping standard staging endpoints for profiles, completed jobs, today's jobs, future jobs, weekly availability slots, and compliance file uploads. Includes graceful `catchError` pipes to seamlessly degrade to local mock data if the API is offline or unauthorized.
- [x] **CORS Proxy Routing Setup**: Configured a reverse proxy rewrite route in `vercel.json` (`/api/*` ➔ `https://staging-api.redtaxi.co.uk/api/*`) and a matching local development configuration `proxy.conf.json`. This completely bypasses all CORS (Cross-Origin Resource Sharing) restrictions, enabling hosted web pages to load live database data securely.
- [x] **Webview Hash Routing and Guard Fixes**: Configured hash routing (`withHashLocation()`) and updated the router guard to parse query tokens placed after the hash (e.g. `/#/bookings?token=XYZ`), preventing redirection loops back to webview logins.
- [x] **Native Flutter Login screen**: Designed a premium, light-themed native login page utilizing custom clippers (`HeaderClipper`), glowing branding badges, and gradient action buttons.
- [x] **Secure Storage Session Cache**: Integrated `FlutterSecureStorage` caching inside `AuthNotifier` to remember driver login states across restarts, alongside connectivity bypasses (Username: `driver` / Password: `driver`) for offline developer previews.
- [x] **Polished Native Dashboard**: Redesigned `dashboard_view.dart` to incorporate high-end widgets (Active/Offline duty toggles with pulsing status dots, Today's earnings metric columns, simplified dev simulation decks, and recent completed trips rows).
- [x] **Native Sign Out Actions**: Embedded logout triggers in the native dashboard App bar that clear cached secure credentials and reset routing guards.

### ⏳ Remaining Work / Roadmap
- [ ] **Real Location Tracking**: Wire up the location service in `lib/core/location` to stream real GPS coordinates to the server.
- [ ] **Native Back Button Handling**: Capture back navigation inside Webviews so users don't exit the app accidentally.
- [ ] **Live Trip State Updates**: Connect Riverpod state to real-time WebSockets (e.g., Pusher) for receiving job offers instead of mock triggers.
