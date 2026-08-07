# Red Taxi — PRD v2d: Dispatch Auth Swap + Browser Notification Replacement

**Version:** 1.0-draft
**Status:** Draft — not yet approved for implementation
**Author:** Red Banana Studios
**Created:** 2026-03-29
**Depends on:** PRD v2a Phase 1 (ClerkUserId + `/api/v2/users/me` exists)
**Parallel with:** PRD v2a (auth), PRD v2b (admin rebuild), PRD v2c (API completion)

> This PRD covers TWO related changes to the dispatch app:
> 1. Auth swap from legacy JWT to Clerk
> 2. Browser notification swap from FCM to Pusher
>
> These are combined because they're both dispatch-specific and both touch the
> app's initialisation layer without changing page logic.

---

## 1. Objective

### Auth swap
Replace the dispatch app's custom JWT auth (AuthContext + localStorage + iframe
postMessage) with Clerk authentication, using the same Clerk org and role
contract defined in `docs/shared-contract-roles.md`.

### Browser notification swap
Replace unreliable browser FCM notifications with Pusher events (already
tenant-scoped from PR #4), with per-event-group audio alerts configured
per-browser in localStorage.

### What this does NOT do
- Does not change any dispatch page logic, booking workflows, or UI
- Does not change real-time Pusher event handling (already working)
- Does not touch driver app mobile push (`NotificationFCM` — separate concern)
- Does not rebuild any dispatch components

---

## 2. Pre-Implementation: Dispatch Role Investigation

**This must be completed before implementation starts.**

The dispatch app has role-dependent behaviour throughout. A full audit is needed
to document every location where `roleId` is checked and what it controls.

### Known role checks (from initial scan)

| File | Pattern | What it does |
|------|---------|-------------|
| `CompleteBookingModal.jsx:37` | `roleId === 3` | Disables price override for drivers |
| `CompleteBookingModal.jsx:85,100` | `roleId === 3` | Disables scope-dependent controls for drivers |
| `CompleteBookingModal.jsx:122` | `roleId === 1` | Shows refund button for admin only |
| `CallerIdPopUp.jsx:19,30,40,45,60` | `roleId === 3` / `roleId !== 3` | Hides caller ID lookup for drivers |
| `CustomDialog.jsx:322,337,400,460,686,706,715,755,784,794` | `roleId !== 3` / `roleId === 1` | Hides cancel, edit, allocate, payment actions from drivers. Shows admin-only refund/credit. |

### Investigation tasks

- [ ] Search all `.jsx` and `.js` files for `roleId`, `role`, `RoleId`, `roleString`
- [ ] Document every check with: file, line, condition, what it shows/hides
- [ ] Confirm the driver-context pattern: where does driver see only own data?
- [ ] Check for any hardcoded user IDs or role assumptions
- [ ] Check Pusher subscription — does it filter events by role?
- [ ] Check if any dispatch pages are completely hidden by role (not just elements)
- [ ] Document findings in `docs/dispatch-role-audit.md`

**This audit informs whether v2d is truly "just an auth swap" or if there are
role-related changes needed.**

---

## 3. Auth Swap — Implementation

### Current auth flow

```
1. User visits /dispatch/login
2. LoginPage.jsx → POST /api/userprofile/login (username + password)
3. Response: { token, userId, roleId, fullName, ... }
4. Stored in localStorage: authToken, userData
5. AuthContext.jsx wraps app, reads from localStorage
6. Protected component checks AuthContext for token
7. All API calls: axios interceptor adds Bearer token from localStorage
8. Iframe postMessage: parent (shell) can pass token to dispatch
```

### Target auth flow

```
1. User visits /dispatch
2. Clerk <SignIn /> component handles login
3. Clerk issues RS256 JWT with org_id claim
4. Frontend: useAuth().getToken() provides Bearer token
5. On load: GET /api/v2/users/me → { userId, roleId, role, permissions }
6. Store userId + roleId in React context (for existing roleId checks)
7. All API calls: axios interceptor uses Clerk token
8. No iframe postMessage needed — Clerk handles cross-domain auth
```

### Step-by-step

**Step 3.1 — Install Clerk React SDK**
```bash
cd src/frontend/apps/dispatch
npm install @clerk/clerk-react
```

**Step 3.2 — Add ClerkProvider to app root**

Replace or wrap the existing app entry point with:

```jsx
import { ClerkProvider } from '@clerk/clerk-react';

<ClerkProvider publishableKey={import.meta.env.VITE_CLERK_PUBLISHABLE_KEY}>
  <App />
</ClerkProvider>
```

**Step 3.3 — Replace AuthContext.jsx**

Current `AuthContext.jsx` manages:
- `token` (string) — JWT from localStorage
- `currentUser` (object) — user data from localStorage
- `login(username, password)` — calls POST /api/userprofile/login
- `logout()` — clears localStorage

Replace with a `UserContext` that wraps Clerk:

```jsx
import { useAuth, useUser } from '@clerk/clerk-react';

const UserContext = createContext(null);

export function UserProvider({ children }) {
  const { getToken, isSignedIn } = useAuth();
  const [me, setMe] = useState(null);

  useEffect(() => {
    if (isSignedIn) {
      // Call /api/v2/users/me to get roleId + permissions
      api.get('/api/v2/users/me').then(res => setMe(res.data.data));
    }
  }, [isSignedIn]);

  return (
    <UserContext.Provider value={{
      currentUser: me,
      isAuth: isSignedIn,
      // Backwards compat: existing code reads user.currentUser.roleId
    }}>
      {children}
    </UserContext.Provider>
  );
}
```

**Step 3.4 — Replace Protected route wrapper**

Current `Protected` component checks `AuthContext` for token.

Replace with Clerk's `useAuth()`:

```jsx
import { useAuth } from '@clerk/clerk-react';
import { Navigate, Outlet } from 'react-router-dom';

export function Protected() {
  const { isSignedIn, isLoaded } = useAuth();
  if (!isLoaded) return <ScreenLoader />;
  return isSignedIn ? <Outlet /> : <Navigate to="/dispatch/sign-in" />;
}
```

**Step 3.5 — Replace login page**

Replace the custom login form with Clerk `<SignIn />`:

```jsx
import { SignIn } from '@clerk/clerk-react';

export function LoginPage() {
  return (
    <div className="login-container">
      <SignIn routing="path" path="/dispatch/sign-in" />
    </div>
  );
}
```

**Step 3.6 — Update axios interceptor**

Current interceptor reads token from localStorage.

Replace with Clerk token:

```jsx
import { useAuth } from '@clerk/clerk-react';

// In app initialisation
const { getToken } = useAuth();

api.interceptors.request.use(async (config) => {
  const token = await getToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});
```

**Step 3.7 — Remove iframe postMessage auth**

The dispatch app currently accepts tokens via `window.postMessage` from the
parent shell app. With Clerk, auth is handled by Clerk's cookie/session — no
need for cross-frame token passing.

Remove:
- postMessage listener in dispatch app
- Token posting from shell app (if it exists)

**Step 3.8 — Remove unused auth code**

- Delete `AuthContext.jsx` (replaced by UserContext + Clerk)
- Delete login form component (replaced by Clerk `<SignIn />`)
- Remove `authToken` and `userData` from localStorage usage
- Remove POST `/api/userprofile/login` call
- Remove POST `/api/driverapp/login` call (if used)

---

## 4. Browser Notification Swap — FCM → Pusher

### Current state

- `ChromeFCM` token stored in `AppUserProfiles` via `UpdateBrowserFCM` endpoint
- Firebase SDK (`firebase` package) initialised in dispatch app
- FCM sends browser push notifications for:
  - Driver rejected booking
  - Driver timeout on booking
  - New web booking
  - Web booking change request
- Unreliable delivery — FCM browser push is inconsistent
- Audio alerts: per-browser settings (already localStorage)

### Target state

- Pusher events (already received by dispatch app) trigger browser notifications
- Browser `Notification` API shows toast when tab is open
- Audio plays per event group with on/off toggle
- Settings stored in localStorage (per-browser, not per-tenant)
- No FCM SDK, no token management

### Step-by-step

**Step 4.1 — Remove Firebase SDK**

```bash
npm uninstall firebase
```

Remove:
- Firebase initialisation code
- FCM token registration
- Service worker for background FCM (if exists)
- Calls to `UpdateBrowserFCM` / `RemoveBrowserFCM` endpoints

**Step 4.2 — Add Pusher notification listener**

The dispatch app already subscribes to tenant-scoped Pusher channels (PR #4).
Add a notification handler that listens for specific events:

```jsx
// In Pusher.jsx or a new NotificationListener component
const channel = pusher.subscribe(`tenant-${orgId}`);

const NOTIFICATION_EVENTS = {
  'booking.driver-rejected': { group: 'driver_reject', sound: 'alert.mp3' },
  'booking.driver-timeout': { group: 'driver_timeout', sound: 'alert.mp3' },
  'booking.web-new': { group: 'web_booking', sound: 'chime.mp3' },
  'booking.web-change-request': { group: 'web_change', sound: 'chime.mp3' },
  'booking.cancelled': { group: 'booking_cancelled', sound: 'warning.mp3' },
};

Object.entries(NOTIFICATION_EVENTS).forEach(([event, config]) => {
  channel.bind(event, (data) => {
    const settings = getNotificationSettings(); // from localStorage
    if (settings[config.group]?.enabled !== false) {
      showBrowserNotification(data.title, data.message);
      if (settings[config.group]?.sound !== false) {
        playSound(config.sound);
      }
    }
  });
});
```

**Step 4.3 — Browser Notification API**

```jsx
function showBrowserNotification(title, message) {
  if (Notification.permission === 'granted') {
    new Notification(title, { body: message, icon: '/favicon.ico' });
  } else if (Notification.permission !== 'denied') {
    Notification.requestPermission().then(perm => {
      if (perm === 'granted') {
        new Notification(title, { body: message, icon: '/favicon.ico' });
      }
    });
  }
}
```

**Step 4.4 — Audio alert settings**

Stored in localStorage per-browser:

```json
{
  "notificationSettings": {
    "driver_reject": { "enabled": true, "sound": true },
    "driver_timeout": { "enabled": true, "sound": true },
    "web_booking": { "enabled": true, "sound": true },
    "web_change": { "enabled": true, "sound": true },
    "booking_cancelled": { "enabled": true, "sound": true }
  }
}
```

Add a small settings panel (gear icon in the notification area) that lets the
user toggle each event group on/off and sound on/off.

**Step 4.5 — Request browser notification permission**

On first login, prompt the user to allow browser notifications:

```jsx
useEffect(() => {
  if (isSignedIn && Notification.permission === 'default') {
    Notification.requestPermission();
  }
}, [isSignedIn]);
```

---

## 5. Files to Change

### Auth swap
| File | Action |
|------|--------|
| `package.json` | Add `@clerk/clerk-react`, remove `@auth0/auth0-spa-js` if present |
| `src/main.jsx` | Wrap with `<ClerkProvider>` |
| `src/context/AuthContext.jsx` | Replace with `UserContext` (Clerk + `/users/me`) |
| `src/components/Protected.jsx` | Replace with Clerk `useAuth()` guard |
| `src/pages/Login.jsx` | Replace with Clerk `<SignIn />` |
| `src/services/api.js` (or equivalent) | Update axios interceptor to use Clerk token |
| `.env.development` / `.env.production` | Add `VITE_CLERK_PUBLISHABLE_KEY` |
| Any postMessage listeners | Remove |

### Browser notification swap
| File | Action |
|------|--------|
| `package.json` | Remove `firebase` |
| Firebase init file | Delete |
| FCM service worker | Delete |
| `src/pages/Pusher.jsx` | Add notification event listeners |
| New: `src/components/NotificationListener.jsx` | Pusher → Browser Notification + audio |
| New: `src/components/NotificationSettings.jsx` | Toggle UI for event groups |
| Static: `public/sounds/alert.mp3` etc. | Audio files for each event group |

---

## 6. What NOT to Change

- **No dispatch page logic changes** — booking forms, allocation, scheduling untouched
- **No Pusher channel changes** — already tenant-scoped, already working
- **No `NotificationFCM` changes** — driver app mobile push is separate
- **No role logic changes** — `roleId` checks stay as-is, just sourced from `/users/me` instead of localStorage
- **No API endpoint changes** — dispatch calls the same endpoints, just with Clerk JWT

---

## 7. Testing Checklist

### Auth
- [ ] Clerk sign-in works at `/dispatch/sign-in`
- [ ] Redirect to sign-in when not authenticated
- [ ] After sign-in: `/api/v2/users/me` returns correct user + roleId
- [ ] Admin user sees full dispatch UI (all actions visible)
- [ ] Staff user sees restricted UI (per existing roleId checks)
- [ ] Driver user sees driver-restricted UI (per existing roleId !== 3 checks)
- [ ] All API calls include Clerk Bearer token
- [ ] Token refresh works (Clerk handles automatically)
- [ ] Sign-out clears session
- [ ] Shell app (`app.redtaxi.co.uk/dispatch`) loads correctly with Clerk

### Browser notifications
- [ ] Browser permission prompt on first login
- [ ] Pusher `booking.driver-rejected` event → browser notification appears
- [ ] Pusher `booking.web-new` event → browser notification appears
- [ ] Audio plays for each event group
- [ ] Settings panel: toggle event group off → no notification for that group
- [ ] Settings panel: toggle sound off → notification appears but no audio
- [ ] Settings persist across page refresh (localStorage)
- [ ] Firebase SDK fully removed (no console errors)
- [ ] No calls to `UpdateBrowserFCM` or `RemoveBrowserFCM`

### Regression
- [ ] Booking creation works
- [ ] Driver allocation works
- [ ] Real-time Pusher events still update dispatch board
- [ ] Caller ID pop-up still works
- [ ] All existing roleId-based UI restrictions still work
- [ ] GPS tracking still updates

---

## 8. Effort Estimate

| Task | Effort |
|------|--------|
| Pre-implementation: dispatch role audit | 2-3h |
| Auth swap (Steps 3.1-3.8) | 4-5h |
| Browser notification swap (Steps 4.1-4.5) | 3-4h |
| Testing | 2-3h |
| **Total** | **11-15h** |

---

## 9. Dependencies

```
PRD v2a Phase 1 (ClerkUserId + /users/me endpoint)
    ↓
Dispatch role audit (pre-implementation task)
    ↓
Auth swap (Steps 3.1-3.8)
    ↓
Browser notification swap (Steps 4.1-4.5) — can start in parallel with auth
    ↓
Testing
```

The role audit and auth swap require v2a Phase 1 to be complete (so Clerk JWT
works and `/users/me` exists). The notification swap has no dependency on v2a
and could theoretically start earlier, but it makes sense to do both together
since they're both dispatch initialisation changes.

---

## 10. Non-Negotiable Rules

- Do NOT change any dispatch page logic — this is an auth + notification swap only
- Do NOT remove `NotificationFCM` — that's driver app mobile push
- Do NOT change Pusher channel subscriptions — they already work
- Do NOT add new roleId checks — use existing patterns
- Do NOT store Clerk tokens in localStorage — Clerk manages its own session
- Audio settings are per-browser (localStorage) — NOT per-user or per-tenant
- Complete the dispatch role audit BEFORE starting implementation

---

*This document is a draft. Approve before any implementation begins.*
