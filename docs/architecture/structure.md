# Red Taxi — Project Dependency Map

**Status:** Implemented (Phase 2 complete)
**Projects:** 7 (.NET 8) — API, Application, Domain, Data, Infrastructure, Shared, Tests
**Database:** PostgreSQL (Railway)
**Handlers:** 241 across 16 feature areas (Phase 3 complete)

## Dependency Graph

```
┌─────────────────────────────────────────────────────┐
│                   RedTaxi.API                        │
│  Controllers · Middleware · DI · Scalar              │
└──────────┬──────────────┬──────────────┬────────────┘
           │              │              │
           ▼              ▼              ▼
┌──────────────┐  ┌────────────┐  ┌──────────────────┐
│ Application  │  │  RedTaxi   │  │   RedTaxi.Data    │
│  Features    │  │   .Infra   │  │  DbContext · EF   │
│  Handlers    │  │  SMS · Pay │  │  Migrations (PG)  │
│  Commands    │  │  Maps      │  └────────┬─────────┘
│  Queries     │  └─────┬──────┘           │
└──────┬───────┘        │                  │
       │                │                  │
       ▼                ▼                  ▼
┌─────────────────────────────────────────────────────┐
│                   RedTaxi.Domain                     │
│  Entities · Events · Enums · Value Objects           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   RedTaxi.Shared                     │
│  Result<T> · PagedList<T> · Guards · Extensions      │
│  ← depended on by all above · depends on nothing →  │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   RedTaxi.Tests                      │
│  Integration tests · WebApplicationFactory           │
│  ← depends on API (for test host) →                 │
└─────────────────────────────────────────────────────┘
```

## Rules

`Application` depends on `Domain` and `Shared`. Never on `Data` or `Infrastructure`.  
`Data` depends on `Domain` and `Shared`. Owns the `DbContext` and all migrations.  
`Infrastructure` depends on `Domain` and `Shared`. Never calls `Application` handlers.  
`API` depends on `Application`, `Data` (DI only), `Infrastructure` (DI only).  
`Shared` depends on nothing within Red Taxi. Third-party NuGet packages only.  

## What Lives Where

| Concern | Project |
|---|---|
| Booking entity, Driver entity | Domain |
| BookingStatus enum | Domain |
| BookingCreated domain event | Domain |
| CreateBooking.Command + Handler | Application |
| AppDbContext, BookingConfig | Data |
| Migration files | Data |
| TwilioSmsClient | Infrastructure |
| RevolutPaymentClient | Infrastructure |
| Result<T>, PagedList<T> | Shared |
| BookingsController | API |
| ProblemDetails middleware | API |
| JWT tenant resolution | Infrastructure |
| ITenantContext interface | Domain or Application |
| Integration tests | Tests |
