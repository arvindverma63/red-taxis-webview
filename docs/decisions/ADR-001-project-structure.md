# ADR-001: Six-Project Solution Structure

**Status:** Accepted  
**Date:** 2026-03

---

## Context

The original codebase is two projects — one API project and one service project.
All business logic, data access, integrations, and shared utilities are mixed together
with no enforced boundaries. This makes the codebase difficult to test, extend, and
reason about, and makes multi-tenancy preparation risky.

## Decision

Split into six projects with clear, enforced dependency rules.

```
RedTaxi.API            — entry point, routing, middleware, DI
RedTaxi.Application    — business logic via MediatR feature slices
RedTaxi.Domain         — core entities, domain events, enums
RedTaxi.Data           — EF Core, DbContext, migrations
RedTaxi.Infrastructure — outbound integrations (SMS, payments, maps)
RedTaxi.Shared         — primitives with zero RT project dependencies
```

Dependency direction: `API → Application → Domain`. `Data` and `Infrastructure`
both depend on `Domain`. `Shared` depends on nothing.

## Consequences

Enables clean separation of concerns, makes each layer independently testable,
removes the possibility of integration code calling business logic directly,
and gives EF migrations a natural home in `RedTaxi.Data` rather than Infrastructure.
