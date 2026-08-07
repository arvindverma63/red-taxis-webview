# Red Taxi — Staging Environment Guide

> **Last updated:** 2026-04-10
> **Owner:** Peter Farrell, Red Banana Studios

---

## Overview

The staging environment is a full production replica running on Peter's always-on PC.
It uses Cloudflare Tunnel to expose local services to the internet over HTTPS, bypassing
the CGNAT limitation on the home network. All services auto-start on boot via NSSM.

**Staging mirrors production exactly:** real SMS (Webex), real email (Resend), real Stripe
(test mode), real Pusher notifications, same database schema, same API code.

---

## Staging URLs

| Service | URL | Local Port |
|---------|-----|------------|
| API | https://staging-api.redtaxi.co.uk | 5092 |
| Admin V2 | https://staging-app.redtaxi.co.uk | 3100 |
| SaaS Admin | https://staging-saas.redtaxi.co.uk | 3101 |
| Account Booker | https://staging-book.redtaxi.co.uk | IIS (80) |
| Dispatch V2 | https://staging-app.redtaxi.co.uk/dispatch-embed/ (same-origin under Admin V2) | IIS (80) virtual dir |
| API Docs | https://staging-api.redtaxi.co.uk/scalar/v1 | 5092 |
| Health Check | https://staging-api.redtaxi.co.uk/health | 5092 |

---

## Architecture

```
Internet
  → Cloudflare Edge (London: lhr01, lhr09, lhr13, lhr18, lhr21)
    → Cloudflare Tunnel (outbound from PC, no port forwarding needed)
      → redtaxi-tunnel service (cloudflared)
        → staging-api.redtaxi.co.uk  → localhost:5092  (.NET API)
        → staging-app.redtaxi.co.uk  → localhost:3100  (Admin V2 Next.js)
        → staging-saas.redtaxi.co.uk → localhost:3101  (SaaS Admin Next.js)
        → staging-book.redtaxi.co.uk → localhost:80    (IIS → static files)
        (dispatch-v2 is served same-origin under Admin V2 at /dispatch-embed/ via an IIS virtual dir — no separate subdomain)

  PostgreSQL → localhost:5432/redtaxi (existing dev database, full production data)
```

### Why Cloudflare Tunnel?

The home network uses an eero router behind ISP CGNAT (WAN IP: 100.86.x.x).
Port forwarding is impossible. Cloudflare Tunnel creates an outbound connection
from the PC to Cloudflare's edge, so no inbound ports are needed.

---

## Windows Services

All services are managed via NSSM (Non-Sucking Service Manager) and auto-start on boot.

| Service Name | Type | What It Runs | Depends On |
|-------------|------|-------------|------------|
| `redtaxi-tunnel` | NSSM | cloudflared tunnel | — |
| `redtaxi-api` | NSSM | `staging/start-api.cmd` → .NET API | — |
| `redtaxi-admin` | NSSM | `staging/start-admin.cmd` → Next.js | — |
| `redtaxi-saas` | NSSM | `staging/start-saas.cmd` → Next.js | — |
| `W3SVC` (IIS) | Windows | Static files for Account Booker + Dispatch | — |
| `Paperclip` | NSSM | PaperclipAI on port 8080 (moved from 80) | — |

### Service Commands (run as Administrator)

```powershell
# Check all service statuses
Get-Service redtaxi-*,W3SVC | Format-Table Name, Status -AutoSize

# Start/stop/restart individual services
C:\nssm\nssm.exe start redtaxi-api
C:\nssm\nssm.exe stop redtaxi-api
C:\nssm\nssm.exe restart redtaxi-api

# Or use the helper scripts
powershell -File staging\start-services.ps1
powershell -File staging\stop-services.ps1
powershell -File staging\restart-services.ps1
```

---

## Configuration Files

### Backend API

| File | Purpose |
|------|---------|
| `src/backend/RedTaxi.API/appsettings.Staging.json` | CORS origins for staging-*.redtaxi.co.uk |
| `src/backend/RedTaxi.API/appsettings.Development.json` | Also contains staging CORS origins (API runs in Dev mode) |
| `staging/start-api.cmd` | All environment variables (secrets, API keys, database URL) |

**Important:** The API runs with `ASPNETCORE_ENVIRONMENT=Staging` set in `start-api.cmd`,
but due to the config loading order, it effectively runs in Development mode. The staging
CORS origins are added to `appsettings.Development.json` as well for reliability.

### Frontend Apps

| App | Staging Config | Build Output |
|-----|---------------|-------------|
| Admin V2 | `src/frontend/apps/admin-v2/.env.staging` | `.next/` (Next.js) |
| SaaS Admin | `src/frontend/apps/saas-admin/.env.staging` | `.next/` (Next.js) |
| Dispatch V2 | `src/frontend/apps/dispatch-v2/.env.staging` | `dist/` (Vite, base=/dispatch-embed/) |
| Account Booker | `src/frontend/apps/account-booker/.env.staging` | `dist/` (Vite) |

All frontends use `NEXT_PUBLIC_USE_DEV_TOKEN=true` / `VITE_USE_DEV_TOKEN=true` because
the API runs in Development mode and issues dev tokens at `/dev/token?user=Peter`.

### Cloudflare Tunnel

| File | Purpose |
|------|---------|
| `C:\Users\peter\.cloudflared\config.yml` | Tunnel routes (hostname → local service) |
| `C:\Users\peter\.cloudflared\47b09ac1-...json` | Tunnel credentials (keep secret) |
| `C:\Users\peter\.cloudflared\cert.pem` | Cloudflare origin cert |

### IIS

| Site | Binding | Physical Path / Proxy Target |
|------|---------|------------------------------|
| `api.rt.ddns.net` | `*:80:api.rt.ddns.net` | → `http://localhost:5092` (reverse proxy) |
| `app.rt.ddns.net` | `*:80:app.rt.ddns.net` | → `http://localhost:3100` + `/dispatch-embed/` virtual dir (dispatch-v2 static files) |
| `rt.ddns.net` | `*:80:rt.ddns.net` | → `http://localhost:3101` (reverse proxy) |
| `book.rt.ddns.net` | `*:80:book.rt.ddns.net` | `O:\RedTaxi\...\account-booker\dist` (static) |

IIS uses URL Rewrite + Application Request Routing (ARR) for reverse proxying.
Web.config files are in `C:\inetpub\sites\{hostname}\web.config`.

---

## Integrations & Webhooks

### Email (Resend)

| Setting | Value |
|---------|-------|
| Provider | Resend |
| API Key | `re_YOUR_API_KEY_HERE` (in start-api.cmd) |
| Sender | `noreply@redtaxi.co.uk` |
| Webhook URL | `https://staging-api.redtaxi.co.uk/api/v2/delivery-status/email/resend` |
| Webhook Events | sent, delivered, bounced, complained, failed, opened, clicked, delivery_delayed |
| Status | **VERIFIED** — email sent + delivered + webhook received |

**Test command:**
```bash
TOKEN=$(curl -s "https://staging-api.redtaxi.co.uk/dev/token?user=Peter" | jq -r .token)
curl -X POST "https://staging-api.redtaxi.co.uk/api/v2/settings/test-email?template=registration&to=peter@abacusonline.net" \
  -H "Authorization: Bearer $TOKEN"
```

### SMS (Webex Interact)

| Setting | Value |
|---------|-------|
| Provider | Webex Interact v1 API |
| Endpoint | `https://api.webexinteract.com/v1/sms` |
| Auth | `X-AUTH-KEY` header |
| API Key | `aky_3CAcJhkJZu9VFETkSsmIL4uEyDX` (staging key, in start-api.cmd) |
| Sender | Per-tenant `SmsSenderId` or default `Ace Taxis` |
| Callback URL | `https://staging-api.redtaxi.co.uk/api/v2/delivery-status/sms/webex` |
| SMS_TESTING | `false` (real SMS enabled) |
| Status | **VERIFIED** — SMS sent + received on phone |

**Important:** The Webex adapter was updated from the old `api.eu.webexconnect.io` endpoint
to the new `api.webexinteract.com` endpoint. This change is in the codebase and needs to
be deployed to production too.

**Test command:**
```bash
TOKEN=$(curl -s "https://staging-api.redtaxi.co.uk/dev/token?user=Peter" | jq -r .token)
curl -X POST "https://staging-api.redtaxi.co.uk/api/v2/messaging/driver" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"driverId": 1, "message": "Staging SMS test"}'
```

Note: Driver 1 has a test phone number (+447700900001) which Webex rejects.
Use a real driver ID or test directly via the Webex API.

### Stripe (Test Mode)

| Setting | Value |
|---------|-------|
| Secret Key | `sk_test_51TFzje...` (in start-api.cmd) |
| Webhook URL | `https://staging-api.redtaxi.co.uk/api/v2/stripe/webhook` |
| Webhook Secret | `whsec_DpIwjLhqtbQ8wxHHN94apAbUWlwkMtxd` |
| Webhook ID | `we_1TKfoM9D0J4wzb0ZTHjyRkgp` |
| Events | checkout.session.completed, customer.subscription.updated, customer.subscription.deleted, invoice.payment_failed |
| Redirect URLs | `staging-saas.redtaxi.co.uk/dashboard` |

### Pusher (Real-time Notifications)

| Setting | Value |
|---------|-------|
| App ID | `2134134` |
| Key | `72a68ffd46f37a9d649a` |
| Cluster | `eu` |
| Shared with production | **Yes** — same Pusher app |

**Warning:** If staging and production use the same tenant org ID, notifications
may cross environments. Use different test org IDs for staging to avoid this.

### Sentry (Error Monitoring)

| Setting | Value |
|---------|-------|
| DSN | Points to production project (shared) |
| Plan | Separate staging project to be created later |

---

## Common Operations

### Deploy Code Changes to Staging

After making code changes, run the full rebuild:

```powershell
# Full rebuild (stops services → builds everything → restarts)
powershell -ExecutionPolicy Bypass -File staging\rebuild.ps1
```

Or rebuild individual components:

```powershell
# API only (must stop first to release file locks)
C:\nssm\nssm.exe stop redtaxi-api
cd src\backend
dotnet publish RedTaxi.API -c Release -o O:\RedTaxi\staging\api-publish --nologo
C:\nssm\nssm.exe start redtaxi-api

# Admin V2 only
cd src\frontend\apps\admin-v2
copy .env.staging .env.production.local
npm run build
C:\nssm\nssm.exe restart redtaxi-admin

# SaaS Admin only
cd src\frontend\apps\saas-admin
copy .env.staging .env.production.local
npm run build
C:\nssm\nssm.exe restart redtaxi-saas

# Dispatch V2 only (must use --base /dispatch-embed/)
cd src\frontend\apps\dispatch-v2
copy .env.staging .env.production.local
set MSYS_NO_PATHCONV=1
npx vite build --base /dispatch-embed/

# Account Booker only (static files, no service restart needed)
cd src\frontend\apps\account-booker
copy .env.staging .env.production.local
npm run build
```

### Verify Staging Health

```powershell
# Full health check script
powershell -ExecutionPolicy Bypass -File staging\verify-staging.ps1

# Quick curl checks
curl https://staging-api.redtaxi.co.uk/health
curl -o /dev/null -w "%{http_code}" https://staging-app.redtaxi.co.uk
curl -o /dev/null -w "%{http_code}" https://staging-saas.redtaxi.co.uk
curl -o /dev/null -w "%{http_code}" https://staging-book.redtaxi.co.uk
```

### View Service Logs

All logs are in `staging/logs/` with automatic rotation at 10MB.

```powershell
# Tail API logs
Get-Content staging\logs\api-stdout.log -Tail 50 -Wait

# Check for errors
Select-String -Path staging\logs\api-stdout.log -Pattern "ERR|WRN" | Select-Object -Last 20

# Tunnel logs
Get-Content staging\logs\tunnel-stderr.log -Tail 20

# Admin/SaaS logs
Get-Content staging\logs\admin-stderr.log -Tail 20
Get-Content staging\logs\saas-stderr.log -Tail 20
```

### Check Tunnel Status

```bash
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info redtaxi-staging
```

Should show 4-6 active connections to London data centers.

### Change SMS Routing (WebEx vs Local Gateway)

```bash
# Switch to WebEx (sends via Webex Interact API)
TOKEN=$(curl -s "https://staging-api.redtaxi.co.uk/dev/token?user=Peter" | jq -r .token)
curl -X PUT "https://staging-api.redtaxi.co.uk/api/v2/settings/messaging/sms-routing" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mode": "WebEx"}'

# Switch to Local Gateway (queues for Android SMS sender app)
curl -X PUT "https://staging-api.redtaxi.co.uk/api/v2/settings/messaging/sms-routing" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"mode": "LocalGateway"}'
```

---

## First-Time Setup (from scratch)

If you need to set up the staging environment on a new machine:

### Prerequisites
- Windows 11 with PostgreSQL 17 (localhost:5432/redtaxi with populated data)
- Node.js 22+ and .NET 8 SDK
- Git clone of the red-taxi repo

### Steps

1. **Install tools:**
   - NSSM: `C:\nssm\nssm.exe` (from https://nssm.cc)
   - Caddy: `C:\Caddy\caddy.exe` (not used currently, IIS replaced it)
   - cloudflared: `C:\Program Files (x86)\cloudflared\cloudflared.exe` (via winget)
   - IIS: Enable via Windows Features, install URL Rewrite + ARR MSI packages

2. **Authenticate cloudflared:**
   ```
   cloudflared tunnel login
   ```
   Select `redtaxi.co.uk` in the browser.

3. **Create tunnel (already done, skip if tunnel exists):**
   ```
   cloudflared tunnel create redtaxi-staging
   cloudflared tunnel route dns redtaxi-staging staging-api.redtaxi.co.uk
   cloudflared tunnel route dns redtaxi-staging staging-app.redtaxi.co.uk
   cloudflared tunnel route dns redtaxi-staging staging-saas.redtaxi.co.uk
   cloudflared tunnel route dns redtaxi-staging staging-book.redtaxi.co.uk
   ```

4. **Create tunnel config** at `C:\Users\peter\.cloudflared\config.yml`:
   ```yaml
   tunnel: 47b09ac1-67fe-4965-badc-259ef102e78b
   credentials-file: C:\Users\peter\.cloudflared\47b09ac1-67fe-4965-badc-259ef102e78b.json
   ingress:
     - hostname: staging-api.redtaxi.co.uk
       service: http://localhost:5092
     - hostname: staging-app.redtaxi.co.uk
       service: http://localhost:3100
     - hostname: staging-saas.redtaxi.co.uk
       service: http://localhost:3101
     - hostname: staging-book.redtaxi.co.uk
       service: http://localhost:80
       originRequest:
         httpHostHeader: book.rt.ddns.net
     - service: http_status:404
   ```

5. **Build all apps:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File staging\build-staging.ps1
   ```

6. **Install services:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File staging\install-services.ps1
   ```

7. **Set up firewall:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File staging\setup-firewall.ps1
   ```

8. **Start everything:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File staging\start-services.ps1
   ```

---

## DNS & Cloudflare

| Setting | Value |
|---------|-------|
| Domain | `redtaxi.co.uk` |
| Cloudflare Account | `Peter@redbananastudios.com` (Free plan) |
| Nameservers | `janet.ns.cloudflare.com`, `martin.ns.cloudflare.com` |
| Zone ID | `10310a72b86c6f1487452534c244b695` |
| Account ID | `6fa3b2164116050f7cf007ecfaabe42f` |
| Tunnel ID | `47b09ac1-67fe-4965-badc-259ef102e78b` |
| SSL | Universal (auto-provisioned by Cloudflare) |

Staging subdomains are CNAME records pointing to the tunnel:
```
staging-api.redtaxi.co.uk  → CNAME → 47b09ac1-...cfargotunnel.com
staging-app.redtaxi.co.uk  → CNAME → 47b09ac1-...cfargotunnel.com
staging-saas.redtaxi.co.uk → CNAME → 47b09ac1-...cfargotunnel.com
staging-book.redtaxi.co.uk → CNAME → 47b09ac1-...cfargotunnel.com
```

Production DNS records (api, app, www) are also on Cloudflare and remain unaffected.

---

## Staging Scripts Reference

All scripts are in the `staging/` directory.

| Script | Purpose | Run As |
|--------|---------|--------|
| `build-staging.ps1` | Build all 5 apps (API + 4 frontends) | User |
| `rebuild.ps1` | Stop → build → start (full redeploy) | Admin |
| `start-services.ps1` | Start all NSSM services | Admin |
| `stop-services.ps1` | Stop all NSSM services | Admin |
| `restart-services.ps1` | Restart all NSSM services | Admin |
| `install-services.ps1` | Register NSSM services (first-time) | Admin |
| `uninstall-services.ps1` | Remove all NSSM services | Admin |
| `setup-firewall.ps1` | Create Windows firewall rules (ports 80, 443) | Admin |
| `verify-staging.ps1` | Full health check (services, ports, DNS, endpoints) | User |
| `start-api.cmd` | API launcher with all env vars | (NSSM) |
| `start-admin.cmd` | Admin V2 Next.js launcher | (NSSM) |
| `start-saas.cmd` | SaaS Admin Next.js launcher | (NSSM) |

---

## Differences from Production

| Aspect | Staging | Production |
|--------|---------|------------|
| Hosting | Local PC + Cloudflare Tunnel | Railway (API) + Vercel (frontends) |
| Database | localhost:5432/redtaxi (dev data) | Railway PostgreSQL (production data) |
| Auth | Dev tokens (no Clerk JWT) | Clerk JWT (RS256) |
| SMS | Webex Interact (staging key) | Webex Interact (production key) |
| Email | Resend (shared API key) | Resend (shared API key) |
| Stripe | Test mode (shared key) | Test mode (shared key) |
| Pusher | Shared app with production | Same |
| Sentry | Shared project (to be separated) | Same |
| SSL | Cloudflare Universal (auto) | Railway/Vercel managed |
| Deploy | Manual (`rebuild.ps1`) | Auto-deploy from `main` branch |
| SMS Routing | WebEx (configurable) | Per-tenant setting |

---

## Troubleshooting

### Services won't start

```powershell
# Check NSSM status
C:\nssm\nssm.exe status redtaxi-api

# Check logs for errors
Get-Content staging\logs\api-stderr.log -Tail 30

# Reset NSSM throttle (if service crashed too many times)
C:\nssm\nssm.exe set redtaxi-api AppThrottle 0
C:\nssm\nssm.exe start redtaxi-api
```

### Port conflicts

```powershell
# Find what's using a port
Get-NetTCPConnection -LocalPort 5092 -State Listen |
  ForEach-Object { Get-Process -Id $_.OwningProcess }

# Common conflicts:
# Port 3000 — Google Maps MCP server (use 3100 for admin instead)
# Port 3100 — Admin V2 staging
# Port 3101 — SaaS Admin staging
# Port 5092 — API
# Port 8080 — PaperclipAI
```

### Tunnel not connecting

```bash
# Check tunnel status
"C:\Program Files (x86)\cloudflared\cloudflared.exe" tunnel info redtaxi-staging

# Should show active connections. If not:
C:\nssm\nssm.exe restart redtaxi-tunnel

# Check tunnel logs
Get-Content staging\logs\tunnel-stderr.log -Tail 20
```

### CORS errors in browser

1. Check `appsettings.Development.json` has the staging origins
2. Republish API: stop service → `dotnet publish` → start service
3. Verify with curl:
   ```bash
   curl -sI -H "Origin: https://staging-app.redtaxi.co.uk" \
     -H "Access-Control-Request-Method: GET" \
     -X OPTIONS http://localhost:5092/health | grep access-control
   ```

### API publish fails (file locked)

```powershell
# Must stop the API service before publishing
C:\nssm\nssm.exe stop redtaxi-api
Start-Sleep 3
# Kill any remaining processes
Get-NetTCPConnection -LocalPort 5092 -State Listen |
  ForEach-Object { Stop-Process -Id $_.OwningProcess -Force }
# Now publish
dotnet publish RedTaxi.API -c Release -o O:\RedTaxi\staging\api-publish
# Restart
C:\nssm\nssm.exe start redtaxi-api
```

### Dispatch iframe not loading

The dispatch is served same-origin as static Vite files at `app.rt.ddns.net/dispatch-embed/`.
It must be built with `--base /dispatch-embed/`:

```bash
cd src/frontend/apps/dispatch-v2
set MSYS_NO_PATHCONV=1
npx vite build --base /dispatch-embed/
```

The `VITE_PARENT_URL` in `.env.staging` must match the admin domain for postMessage auth.

---

## Security Notes

- **All API keys and secrets** are in `staging/start-api.cmd` (gitignored)
- **Cloudflare tunnel credentials** are in `C:\Users\peter\.cloudflared\` (not in repo)
- **Dev tokens** bypass Clerk auth — staging is NOT suitable for security testing
- **SMS_TESTING=false** — real SMS will be sent and charged to the Webex account
- **Stripe is in test mode** — no real charges, but webhooks fire for real
- **Same Resend API key as production** — emails sent from staging use the same sender domain
