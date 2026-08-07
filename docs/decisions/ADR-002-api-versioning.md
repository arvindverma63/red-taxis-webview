# ADR-002: Parallel v1/v2 API Versioning via Shared Handlers

**Status:** Accepted  
**Date:** 2026-03

---

## Context

The existing API has a frontend consuming `/api/v1` routes. During the refactor,
new clean handlers are being introduced. We need both old consumers to continue
working uninterrupted while giving new consumers (and migrating old ones) a
cleaner, consistently-shaped API surface.

## Decision

Both v1 and v2 routes point to the same MediatR handler. There is no duplicated
logic. v1 routes are never modified — only the handler behind them is cleaned up.
v2 routes are added when a feature slice is created in Phase 3.

v2 responses follow a consistent envelope `{ success, data, errors }`.
v1 responses remain exactly as they are today.

v1 routes are retired per-endpoint only after the frontend confirms migration.

## Consequences

Bug fixes in the handler automatically fix both versions. There is no risk of
v1 and v2 diverging in behaviour. The dual-fix problem is eliminated. The frontend
can migrate at its own pace with no operational risk. v1 retirement is controlled
and explicit rather than implicit.
