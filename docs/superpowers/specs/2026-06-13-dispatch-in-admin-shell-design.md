# Dispatch-in-Admin-Shell — Same-Origin Integration

**Date:** 2026-06-13
**Branch:** `feature/dispatch-in-admin-shell`
**Decision owner:** Peter

## Goal

Dispatch-v2 stays a **separate app** (React 18 / Vite / MUI / Redux — not ported into
admin-v2's React 19 / Next stack), but is presented as **one site, one login**:

- Served **same-origin** under the admin domain at `app.redtaxi.co.uk/dispatch`
  (no `*-dispatch.*` subdomain).
- Embedded **inside the admin shell** via iframe (sidebar/header stay around it).
- **Single auth:** a same-origin iframe shares `localStorage` with the parent, so
  dispatch reads admin-v2's `authToken` directly. No second login, no postMessage
  handshake required, no CORS.

## Why this shape (recap of the decision)

Full-porting dispatch into admin's stack is a large, risky rewrite of working software
(82 vitest tests green) for a benefit — single URL/login — achievable without it. Two
React majors can't share one DOM tree, and MUI 5 isn't React-19-safe. The iframe gives
hard isolation (separate React, bundles, deploy cadence) as a *feature*. The only real
upgrade over today is **same-origin** serving, which removes the cross-origin friction
(separate subdomain → postMessage + CORS).

## Current state (dev)

- `admin-v2/src/app/(dashboard)/dispatch/page.tsx` renders
  `<iframe src={NEXT_PUBLIC_HEADLESS_DISPATCH_URL}>` (a **separate subdomain**) and
  posts `{token, username, userData}` to it via `postMessage`, re-sending on refresh.
- `dispatch-v2` `AuthContext` in `IFRAME_MODE` listens for that message, writes
  `authToken` to localStorage, then fetches the user.
- Staging IIS (`app.rt.ddns.net`) **already** serves `/dispatch/` as a virtual dir from
  the dispatch `dist` built with `--base /dispatch/` — i.e. staging is already
  same-origin-capable; only the admin env var points the iframe at the subdomain.

## Target architecture

Serve the dispatch **static build at base `/dispatch/` in every environment**, under the
admin origin:

| Env | Mechanism |
|-----|-----------|
| Local dev | `admin-v2` Next `rewrites()` proxies `/dispatch/:path*` → `http://localhost:5173/dispatch/:path*`; run dispatch dev as `vite --base /dispatch/` |
| Staging | IIS virtual dir `/dispatch/` → dispatch `dist` (already in place) |
| Production (Vercel) | **Documented only — NOT deployed as part of this work.** `admin-v2` Next `rewrites()` would proxy `/dispatch/:path*` → dispatch-v2 deployment; dispatch built `--base /dispatch/`. Production cutover (Railway/Vercel) is a separate, Peter-controlled, paid step. |

Asset base path is the crux: every dispatch asset URL must be `/dispatch/...` so the
proxy/virtual-dir catches it. Hence `--base /dispatch/` everywhere (dev included).

**Cost guardrail:** all build + verification for this work happens on **free local
infrastructure only** — local dev stack + local staging (Peter's PC). No Railway/Vercel
deploys, no new paid projects. See CLAUDE.md "Cost guardrail".

## Changes

1. **admin-v2 `next.config.ts`** — add `async rewrites()` returning
   `{ source: '/dispatch/:path*', destination: `${DISPATCH_ORIGIN}/dispatch/:path*` }`
   when `DISPATCH_ORIGIN` is set (server-side env; not `NEXT_PUBLIC`).
2. **admin-v2 dispatch page** — `iframe src="/dispatch/"` (same-origin relative). Drop
   the postMessage auth path (shared localStorage covers it); keep a minimal
   same-origin postMessage only if needed for logout signalling. Remove the
   `NEXT_PUBLIC_HEADLESS_DISPATCH_URL` "not configured" guard.
3. **dispatch-v2 auth** — in iframe mode, read `authToken` from the shared localStorage
   on mount instead of waiting for postMessage; keep reading it fresh per request
   (already does) so parent refreshes are picked up transparently.
4. **dispatch-v2 build/base** — `--base /dispatch/` for dev (script/flag), staging
   (already), and prod (Vercel build command). Confirm `vite` HMR works under the base.
5. **Env** — replace `NEXT_PUBLIC_HEADLESS_DISPATCH_URL` with server-side
   `DISPATCH_ORIGIN` in admin-v2 `.env.development` (`http://localhost:5173`) and prod
   Vercel env (dispatch Vercel URL). Staging admin doesn't need it (IIS handles it).
6. **CORS** — dispatch API calls now originate from the admin origin
   (`app.redtaxi.co.uk`), already allow-listed. The dispatch subdomain entries can be
   dropped (see legacy-archive work).

## Verification (must run before claiming done)

1. **Local stack**: backend API (5092) + `vite --base /dispatch/` (5173) +
   `admin-v2` dev (3000). Browse `localhost:3000/dispatch`, confirm via Playwright:
   dispatch loads inside the admin shell, **no second login**, bookings/grid render
   with live data, token refresh keeps dispatch working (wait > access-token TTL).
2. **Local staging** (Peter's PC, free — after merge + local rebuild): repeat on
   `staging-app.redtaxi.co.uk/dispatch`. This is the production-like test bed; no paid
   services involved.
3. Assets all load from `/dispatch/...` (network tab — no 404s to admin root).

## Rollback

Revert the env var to the dispatch subdomain + restore the postMessage path. The
dispatch app and its own deployment are untouched, so rollback is config-only.

## Out of scope (separate work)

- Archiving v1 `dispatch` + `headless-dispatch` (the legacy-archive branch).
- The staging cutover to dev (staging hygiene).
- Any port of dispatch into admin's stack (explicitly rejected).

---

## Implementation outcome — VERIFIED LOCALLY 2026-06-13

**Path decision changed during build:** admin-v2 already owns a `/dispatch` page (the
shell + iframe), so the dispatch *app* is served at a **distinct** same-origin path
**`/dispatch-embed`** to avoid colliding with that route. User-facing URL stays `/dispatch`
(the shell); the iframe loads `/dispatch-embed`.

**Final wiring:**
- `admin-v2/next.config.ts` — `rewrites()`: `/dispatch-embed` + `/dispatch-embed/:path*`
  → `${DISPATCH_ORIGIN}/dispatch-embed/...` (only when `DISPATCH_ORIGIN` set).
- `admin-v2 .../dispatch/page.tsx` — iframe `src="/dispatch-embed"`; postMessage
  `targetOrigin = window.location.origin` (same-origin); removed the old
  `NEXT_PUBLIC_HEADLESS_DISPATCH_URL` env + guard.
- `dispatch-v2` served at base `/dispatch-embed/` — scripts `dev:embed` /
  `build:embed` added. Auth keeps the existing iframe postMessage path, now same-origin
  (`VITE_PARENT_URL` = admin origin).
- Env (gitignored, per-machine): admin-v2 `.env.development` sets
  `DISPATCH_ORIGIN=http://localhost:5175`; dispatch-v2 `.env.development` sets
  `VITE_PARENT_URL=http://localhost:3000`, `VITE_BASE_URL=http://localhost:5092`.

**Local run (free, no paid services):**
```
# reuse the already-running local API on :5092 (dev-token enabled)
cd src/frontend/apps/dispatch-v2 && npm run dev:embed        # vite :5175 base /dispatch-embed/
cd src/frontend/apps/admin-v2  && npx next dev -p 3000 -H 0.0.0.0
# browse http://localhost:3000/dispatch
```

**Verified (Playwright, localhost:3000/dispatch):** dispatch-v2's booking console +
today's scheduler render **inside the admin shell** (admin sidebar/header wrap it),
**single login** (dev-token auth, no dispatch login screen), live data. Remaining console
errors are **pre-existing dispatch-v2 bugs** (`CustomDriverAvailabilityChart.jsx` invalid
date / undefined length) + a Sentry 429 + a Redux non-serializable-Date warning — not
caused by the integration.

**Still to verify:** token-refresh survival across the 15-min access-token TTL (postMessage
re-send path unchanged but not yet exercised end-to-end).

**For local staging (next):** build dispatch with `build:embed` and serve its `dist` from
an IIS virtual dir at **`/dispatch-embed/`** under the admin site (rename from the old
`/dispatch/` headless dir). Production (Vercel) remains documented-only — not deployed.
