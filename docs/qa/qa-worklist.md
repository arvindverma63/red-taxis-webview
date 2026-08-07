# QA Loop Worklist

Living worklist driving the continuous QA loop on branch
`claude/red-taxi-admin-qa-check-y8fozw`. Each loop iteration: pick the top
unchecked item, deep-dive, fix safe findings (commit + push), report risky
ones in `2026-06-10-qa-report.md`, tick the box, re-run affected builds.
When all boxes are ticked, switch to re-sweep mode (re-run builds/lint,
re-check CI + PR status, look for new findings) until Peter stops the loop.

Fix policy: safe fixes only; logic changes & security items report-only
(see the report for the standing list). Never touch v1 routes or business
logic silently.

## Queue

- [x] **admin-v2 lint debt batch 1** (iter 1, 2026-06-10) — all errors in
      `components/admin/` cleared: render-time state adjustment in
      account/driver-select, geocode effect with cancellation in
      postcode-heatmap (also fixes a stale-overwrite race), dataUpdatedAt
      instead of Date.now() in direct-message-dialog, sms-status-widget
      migrated to TanStack Query with refetchInterval. Build + tsc clean.
- [x] **admin-v2 lint debt batch 2** (iters 2-3, 2026-06-10) — **0 lint
      errors across the whole app** (was 58). Page-reset effects in 12
      list pages, form-dialog sync effects in 6 dialogs, settings sync
      (3 sites) + Google Maps loader lazy init, school-tariffs dialog,
      turndowns lazy date init, dispatch sendAuth self-reference, routes
      debounce IIFE, and reports/availability: chart components hoisted
      to module scope (were recreated, losing state, every render) +
      driverCell moved below the maps it closes over (React Compiler can
      now optimize the page). Build + tsc clean.
- [x] **admin-v2 lint debt batch 3** (iter 4, 2026-06-10) — **lint fully
      clean: 0 errors, 0 warnings** (day started at 58/72). 60 unused
      imports/vars removed (incl. dead sortRows fn and an unused
      handleExport param + its call site), 8 `data ?? []` logical
      expressions wrapped in useMemo so downstream memo deps are stable,
      SCOPE_LABEL hoisted to module scope, qr-code-preview ref-cleanup
      capture + placeholder-init (update effect owns the url), 2
      justified eslint-disables for data-URL/API-host <img>. Build +
      tsc clean.
- [x] **API: WhatsApp feature deep-dive + merge-loss cross-check**
      (iter 5, 2026-06-10) — diffed every file 17ce253 touched against
      70ce173. Two losses found: the controller endpoints (restored in
      iter 0) and **MessageService.SendWhatsAppMessage's catch block
      emptied** — failures were silently swallowed so the
      SendWhatsAppMessage handler reported success on failed sends.
      Restored log + rethrow. AiAgentController deletions were the
      intentional DB→in-memory route-cache upgrade, not losses.
      Orchestrator/ConversationService only gained code. Settings
      whatsapp-dispatch + test-whatsapp endpoints intact.
- [x] **API: dispatch SMS fallback paths** (iter 5, 2026-06-10) — all 4
      verified intact in DispatchService: allocated (~513), amended
      (~664), unallocated (~768), cancelled (~867). Each gates on
      CheckWhatsAppDispatchReady() (tenant toggle + balance) and sends
      SMS when not ready. Observation (no change made): fallback is
      gate-based only — a WhatsApp send that throws mid-call does not
      retry over SMS. Matches original design.
- [x] **API: controller hygiene scan** (iter 6, 2026-06-10) — V2
      controllers effectively clean. One refactor candidate (not a bug):
      DeliveryStatusController builds a tenant DbContext inline for
      Twilio callbacks; belongs in a handler. See report addendum.
- [x] **API: AllowAnonymous inventory** (iter 6, 2026-06-10) — 31 total:
      5 justified (Twilio/Stripe signature-validated webhooks + public
      plans), 26 IntelligenceController + stt-compare known issues, and
      one NEW finding: POST /api/v2/availability/reminder anonymous with
      hardcoded query key "ace@taxis" (also a tenancy violation). All
      report-only per Peter. Table in report addendum.
- [x] **driver-app static audit** (iter 7, 2026-06-10) — removed the
      268-line dead commented ProfileScreen block; logger-endpoint
      default already cleaned on dev; 12 silent catch blocks + the
      ace-server.1soft.co.uk base-URL question documented in the report
      (no Dart logic changes without a device to verify).
- [x] **local-sms-v2 static audit** (iter 8, 2026-06-10) — clean. QR
      "error swallowing" was a false alarm (errors logged + surfaced;
      only dispose-time cleanup is silent). WorkManager = documented
      safety net. Note: R8 mapping not archived + no crash reporter —
      release stacks undeobfuscatable. Timeout-assumes-sent stays in
      the needs-decision list.
- [x] **Cross-check intelligence merge losses** — completed as part of
      iter 5 (same diff pass): every file 17ce253 touched was compared
      against 70ce173; the two losses found are fixed (controller
      endpoints, SendWhatsAppMessage catch).
- [x] **admin-v2 pattern compliance** (iter 9, 2026-06-10) — checked
      app-wide via grep, not sampled: no <Input type="date">, no const
      pageSize, all chart Tooltips have chartCursor, money formatting
      compliant. PASS.
- [x] **Re-verify draft PR CI** (iter 9, 2026-06-10) — green (run #11,
      both jobs). Test step executes the suite (~15s) with failures
      visible; non-blocking until a seeded CI database exists.

**Sweep 1 complete.** Sweep 2 queue below (started 2026-06-10 PM).

## Sweep 2 Queue

- [x] **Backend: async void audit** (sweep 2 iter 1) — 10 messaging
      methods converted to async Task with explicit discards at 14 call
      sites; MAUI legacy module left as-is. 198/198 tests pass.
- [x] **Backend: handler logging spot-check** (sweep 2 iter 1) — all
      297 handlers have Log.ForContext. PASS.
- [x] **Dependencies: vulnerability scan** (sweep 2 iters 1-2) — NuGet:
      13 found, 12 eliminated via WatchDog.NET removal (all 3 Criticals);
      AutoMapper High reported for v13 migration. npm: CRITICAL Clerk
      auth-bypass advisories (GHSA-vqx2-fgx2-5wq9 + GHSA-w24r-5266-9c3c)
      patched in-range across all 4 apps, npm audit now zero Clerk
      advisories; remaining moderates documented.
- [x] **Frontend: other 3 apps health check** (sweep 2 iter 2) —
      headless-dispatch + account-booker build clean (chunk-size
      warnings only). saas-admin: tsc clean, vitest was 7/8 — the
      failure caught a REAL bug: Footer.footer_text missing from the en
      locale (English landing footer copyright failed to render). Key
      added, 8/8. Build requires the 2 Clerk env vars (passes with them
      present — Vercel-side fine).
- [x] **Backend: EF migration sync check** (sweep 2 iter 2) — probe
      migration generated against RedTaxiDbContext came out EMPTY:
      model and snapshot in sync. Probe removed.
- [x] **Repo: credentials grep** (sweep 2 iter 1) — src/ clean (one
      test dummy). staging/start-api.cmd holds ~12 live secrets (not
      just Twilio) — full rotation needed at scrub time. Report-only.


## Done

- [x] Iteration 0 full sweep (2026-06-10) — see `2026-06-10-qa-report.md`.
      5 fixes committed, 5 issue #48 items verified already-fixed, 6 logic
      items + 4 security items verified still-open and reported.
