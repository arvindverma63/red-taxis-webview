# Project Requirements & Progress Document (PRD)

This document serves as the high-level source of truth for the **Red Taxis Webview** project. It provides an immediate overview of the system architecture, code organization, integration points, completed work, and remaining tasks so that developers and AI agents can get up to speed without reading the entire repository.

---

## 🎯 Project Overview
Red Taxis Webview is a hybrid driver portal system consisting of:
1. **Flutter Mobile App (`src/mobile/driver_app`)**: A native application for drivers. It handles device services (location, auth, navigation, etc.) and uses standard Webviews for server-rendered or static components.
2. **Angular Webview App (`src/frontend/apps/driver-webview-app`)**: A web portal deployed to Vercel that is embedded directly into the native Flutter application's bottom navigation tabs.

---

## 🛠️ Technology Stack & Hosting
- **Native Shell**: Flutter (Dart) with Riverpod for state management and `webview_flutter` for rendering the web pages.
- **Web Portal**: Angular 21 with Vitest for testing.
- **Hosting**:
  - Web Portal is hosted on Vercel at [https://red-taxis-webview-yplz.vercel.app](https://red-taxis-webview-yplz.vercel.app).
  - Configured in Flutter via [constants.dart](file:///d:/redtaxis/src/mobile/driver_app/lib/core/config/constants.dart).

---

## 📁 Repository Structure
- `src/mobile/driver_app/` - The Flutter mobile codebase.
  - `lib/core/config/constants.dart` - App configuration and webview base URLs.
  - `lib/core/location/` - Device location tracking services.
  - `lib/core/widgets/` - Shared UI widgets.
  - `lib/features/` - Feature modules (Auth, Dashboard, Earnings, Shift, Trip, Webview).
- `src/frontend/apps/driver-webview-app/` - The Angular frontend codebase.
  - `src/app/faq/` - Frequently Asked Questions view.
  - `src/app/terms/` - Terms and Agreement view.
  - `src/app/reports/` - Weekly statements and reports view.
  - `src/app/app.routes.ts` - Routing configuration for web pages.
- `docs/` - System architecture and product requirements documents.

---

## 🔄 Integration Details (Flutter ↔ Webview)
The Flutter app embeds the Angular app via three sub-routes configured in `BottomNavigationBar`:
1. **Weekly Reports** ➔ `/reports`
2. **Help & FAQs** ➔ `/faq`
3. **Driver Terms** ➔ `/terms`

---

## 📊 Development Status & Roadmap

### ✅ Completed Work
- [x] **Project Repository Setup**: Git repository initialized and linked to GitHub remote `https://github.com/developer1379/red-taxis-webview.git`.
- [x] **Angular Frontend Web App**: Ported or scaffolded with FAQ, Terms, and Reports pages.
- [x] **Vercel Hosting**: Web app deployed to Vercel (`https://red-taxis-webview-yplz.vercel.app`).
- [x] **Flutter Base URL Setup**: Updated [constants.dart](file:///d:/redtaxis/src/mobile/driver_app/lib/core/config/constants.dart) to point to the live Vercel URL for both development and production.
- [x] **Mobile App Base Layout**: Bottom navigation shell with indexed stack tabs for Dashboard and the three Webview pages.
- [x] **Trip State Machine (Mocked)**: Riverpod state notifier simulating trip lifecycles (Offered ➔ Accepted ➔ En Route ➔ Arrived ➔ On Trip ➔ Completed).
- [x] **Driver Shift Management (Mocked)**: Toggle offline/online shift states.
- [x] **Security Audit**: Removed plaintext API keys from staging documentation to pass GitHub secret scan.

### ⏳ Remaining Work / Roadmap
- [ ] **Authentication Integration**: Hook up `AuthNotifier` in the Flutter app to talk to the backend authentication APIs (currently using simulated/mock login).
- [ ] **Secure Webview Token Passing**: Pass authentication tokens securely from Flutter shell to the Angular webview (e.g., via URL params, cookies, or JavaScript channels/postMessage) to load authenticated user statements in `/reports`.
- [ ] **Real Location Tracking**: Wire up the location service in `lib/core/location` to stream real GPS coordinates to the server.
- [ ] **Native Back Button Handling**: Capture back navigation inside Webviews so users don't exit the app accidentally.
- [ ] **Live Trip State Updates**: Connect Riverpod state to real-time WebSockets (e.g., Pusher) for receiving job offers instead of mock triggers.
