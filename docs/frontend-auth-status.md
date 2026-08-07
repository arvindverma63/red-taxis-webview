# Frontend Auth Status — All Apps

Last updated: 2026-04-06

## Active Apps (all on Clerk)

| App | Auth | Framework | Status |
|-----|------|-----------|--------|
| **admin-v2** | Clerk v7 (`@clerk/nextjs`) | Next.js 16 | Complete — production at app.redtaxi.co.uk |
| **saas-admin** | Clerk v6 (`@clerk/nextjs`) | Next.js 14 | Complete — production at www.redtaxi.co.uk |
| **dispatch-v2** | Internal JWT (iframe postMessage + dev token) | Vite/React 18 | Dispatch console — served same-origin under admin-v2 at `/dispatch-embed`, embedded on the `/dispatch` page via iframe |
| **account-booker** | Clerk (`@clerk/clerk-react`) | Vite/React 18 | Complete — hybrid (Clerk + dev token) |

## Removed From Repo (2026-06)

| App | Auth | Notes |
|-----|------|-------|
| **admin** (v1) | Custom JWT + Auth0 + Firebase | Removed from repo (2026-06). Replaced by admin-v2. Extensive v1 auth: custom login, signup, 2FA, password reset. |
| **dispatch** (v1) | Custom JWT | Removed from repo (2026-06). Replaced by dispatch-v2 embedded in admin-v2. Simple password login. |
| **headless-dispatch** | Clerk (`@clerk/clerk-react`) | Removed from repo (2026-06). Superseded by dispatch-v2 served same-origin at `/dispatch-embed`. |
| **shell** | N/A | Removed from repo. Was a routing shell for v1 admin + dispatch. |

## Auth Modes by App

### admin-v2
- **Production**: Clerk JWT → backend validates RS256 via MultiAuth
- **Local dev**: `NEXT_PUBLIC_USE_DEV_TOKEN=true` → fetches `/dev/token?user=Peter` (HS256)
- **Key files**: `src/lib/hooks/use-api-token.ts`, `src/app/layout.tsx`

### saas-admin
- **Production**: Clerk JWT
- **Local dev**: `NEXT_PUBLIC_USE_DEV_TOKEN=true` → fetches `/dev/token?user=Peter`
- **Key files**: Root layout with ClerkProvider

### dispatch-v2
- **Same-origin embed**: served under admin-v2 at `/dispatch-embed` and loaded in an iframe on the `/dispatch` page. Receives the internal JWT from admin-v2 via postMessage; no auth SDK init in iframe mode.
- **Serving mechanism**: in local dev and production, admin-v2's Next.js `rewrites()` proxy `/dispatch-embed/*` to the dispatch build (`DISPATCH_ORIGIN`); on staging it is served by an IIS virtual dir at `/dispatch-embed/`. Builds with `--base /dispatch-embed/` (scripts `dev:embed` / `build:embed`).
- **Local dev**: `VITE_USE_DEV_TOKEN=true` → "Sign in as Peter (Dev)" button when run standalone

### account-booker
- **Clerk mode**: ClerkProvider + `<SignIn>` component
- **Local dev**: `VITE_USE_DEV_TOKEN=true` → "Sign in as Peter (Dev)" button
- **Key files**: `src/context/AuthContext.jsx`, `src/context/ClerkAuthBridge.jsx`
- **Note**: Axios interceptor auto-injects Bearer token from `localStorage.authToken`

## Backend Compatibility

The backend `Program.cs` has a `MultiAuth` policy scheme:
- **RS256** (Clerk JWT) → routed to Clerk validation scheme
- **HS256** (internal JWT) → routed to Internal validation scheme (for dev tokens + mobile apps)

Both schemes work simultaneously. `CurrentUserMiddleware` resolves the user from either token type.

## What's Left (Backend)

With all frontends on Clerk, the backend can now:
1. **Remove ALL UserManager read-only calls** → direct DbContext queries (v2a Phase 2.3-2.4)
2. **Remove password-related methods** → Clerk handles all password management
3. **Eventually remove Internal auth scheme** → once mobile apps migrate (external repo)
4. **Delete legacy auth code** → AuthenticationService, JwtMiddleware, AppRefreshTokens (v2a Phase 4)

## Mobile Apps (External Repo)

Mobile driver apps still use v1 password login. The Internal auth scheme in the backend MUST stay until mobile migrates. Password-related Identity methods (`CreateAsync`, `CheckPasswordAsync`) can be moved to a dedicated mobile-only service when ready.
