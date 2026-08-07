# Documentation Drift Audit — 2026-04-07

## Scope

This inspection focused on high-churn project docs and compared claims against current admin-v2 source-of-truth files:

- `docs/admin-v2-progress.md`
- `docs/prd-v2b-admin-rebuild.md`
- `docs/frontend-auth-status.md`
- `src/frontend/apps/admin-v2/src/lib/navigation.ts`
- `src/frontend/apps/admin-v2/src/app/**/page.tsx`

## Drift Findings

### 1) Route counts were contradictory across docs

Before this pass, `docs/admin-v2-progress.md` simultaneously claimed:

- "64 routes live"
- "50 routes"
- "51 routes"
- "52 total including hidden placeholders"

These numbers were not internally consistent and did not align to the code inventory.

### 2) PRD completion metadata had stale route totals

`docs/prd-v2b-admin-rebuild.md` still reported "51 routes live" despite current route inventory being higher.

### 3) Route-count definitions were missing

Docs used "routes" in multiple senses (sidebar routes, implemented pages, production-exposed routes) without explicit definitions, which caused the drift.

## Reconciled Baseline (as of 2026-04-07)

- **58 dashboard routes with `page.tsx` files** (excluding pattern demos and style-guide)
- **54 sidebar-exposed routes** from `APP_NAV_SECTIONS`
- **4 non-nav routes** (`/profile`, `/reports/completed`, `/reports/on-shift`, `/web-bookings/rejected`)

## Changes applied in this session

1. Updated `docs/admin-v2-progress.md` to:
   - replace conflicting headline route claims with a reconciled route inventory section,
   - remove hardcoded conflicting totals in section headings,
   - align totals with current navigation and app route files.

2. Updated `docs/prd-v2b-admin-rebuild.md` metadata:
   - changed status line from 51-route claim to the reconciled 58/54+4 breakdown,
   - updated "Updated" date to 2026-04-07.

## Guardrails to prevent future drift

- Always include route-count **definition** next to route-count **number**.
- When adding/removing pages, update both:
  - `src/frontend/apps/admin-v2/src/lib/navigation.ts`
  - `docs/admin-v2-progress.md` route inventory block.
- For future session handovers, prefer one canonical metric block over repeated totals throughout the document.
