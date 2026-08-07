# Voice Agent Performance Tracking Log

Records the history of improvements to the Red Taxi voice agent address intelligence system during the April 12-13 2026 development session.

## Performance History

| Date | Change | Before | After | Evidence |
|------|--------|--------|--------|----------|
| Apr 12 | Starting baseline | External API called on every lookup | Median lookup: 104ms | Profiled via test harness |
| Apr 12 | Starting baseline | "Tesco's" (apostrophe variants) | Not found -- apostrophe blocked match | Manual test call |
| Apr 12 | Starting baseline | "Tesco" lookup | 5 duplicate candidates including Warminster | Manual test call |
| Apr 12 | Starting baseline | "the football club" | Returned Riversmeet Leisure Centre (wrong) | Manual test call |
| Apr 12 | Starting baseline | "Addison Close" spoken by caller | Agent did not call lookup_address | Call transcript review |
| Apr 12 | Starting baseline | Booking with no phone number | Generic "system error" message | Call transcript review |
| Apr 12 | Starting baseline | Availability check | Day-level only ("we have drivers that day") | Call transcript review |
| Apr 12 | Apostrophe stripping (5 Unicode variants) | "Tesco's" not found | "Tesco's" normalised to "Tesco", auto_resolved | Tested all 5 apostrophe chars |
| Apr 12 | Same-town auto-resolve filter | "Tesco" returned 5 candidates (incl. Warminster) | "Tesco" returns 1 candidate (local match) | Test query verified |
| Apr 12 | Full postcode dedup (was outward-code only) | "the football club" resolved to Riversmeet | Riversmeet no longer returned as false match | Test query verified |
| Apr 12 | Missing phone error handling | Generic "system error" | Agent instructed to ask caller for phone number | Updated agent prompt |
| Apr 12 | MonthlyCounterResetService fix | Crash-loop on startup | Service starts cleanly | Sentry error cleared |
| Apr 12-13 | Town/area detection | "mere" returned ambiguous results | Agent asks "whereabouts in Mere?" | Test query verified |
| Apr 12-13 | Local shorthand aliases | "the red" / "con club" not recognised | "the red" resolves to Red Lion, "con club" resolves to Coronation Club | Intelligence alias lookup |
| Apr 12-13 | ASR corrections added | "shatesbury", "jillingham", "gros morales", "grove night", "Tinsbury", "Sharsbury" all failed | All resolve to correct locations (Shaftesbury, Gillingham, Grosvenor, Grove Night, Tisbury, Shaftesbury) | Mishearing alias pipeline |
| Apr 12-13 | Curated town defaults | Co-op Mere / High Street Wincanton unresolvable | Both resolve via curated defaults | Intelligence lookup |
| Apr 12-13 | Football club aliases fixed | "football club" pointed to Riversmeet Leisure Centre | Points to correct football club location | Alias table corrected |
| Apr 12-13 | Udder Farm Shop alias | Not in intelligence DB | Resolves via alias | Intelligence lookup |
| Apr 12-13 | Salisbury District Hospital alias | Not in intelligence DB | Resolves via alias | Intelligence lookup |
| Apr 13 | Smart availability (CheckSlotAvailability) | Day-level only check | Shift hours + job overlap + MPV filter | Verified against Nov 10-14 data + Apr 20 synthetic |
| Apr 13 | Call flow reorder | Addresses collected first, then time | Time collected first, then availability check, then addresses | Agent prompt updated |
| Apr 13 | V2 Address Search (3 new endpoints) | All lookups via external API (104ms median) | In-memory intelligence lookup (1ms median) -- 100x improvement | 20-query benchmark |
| Apr 13 | AI agent wired to v2 search fallback | Single lookup path (external API) | Three-tier: POI hot list, in-memory scan, then v2 API fallback | Agent tool config |
| Apr 13 | ASR keyword optimisation -- remove generic roads | 3,543 STT bias terms (incl. 1,771 generic road names) | 1,772 focused terms (generic roads removed) | Keyword list diff |
| Apr 13 | ASR keyword optimisation -- remove low-frequency | Remaining list included 1,573 terms with < 10 occurrences | ~600 high-signal keywords (was 380 hardcoded before pipeline) | Frequency analysis |
| Apr 13 | STT self-improvement layer (SttComparisonService) | No automatic learning from misheard words | AssemblyAI vs ElevenLabs comparison, auto-adds aliases for confirmed mishearings | Triggered on Twilio call-end callback |
| Apr 13 | On-demand STT test endpoint | Manual-only testing | Endpoint available for manual trigger of comparison | API endpoint live |
| Apr 14 | Route intelligence cache (bidirectional) | Quote relied on Google Distance Matrix (3-4 calls per quote, 84-107ms server time) | O(1) in-memory lookup on bidirectional postcode key, skips Google entirely | Staging measurement |
| Apr 14 | New Stage 6 in pipeline (per-tariff pricing) | `intelligence_popular_routes` stored only AverageFare (mean, outlier-sensitive) | `intelligence_routes`: median JourneyMiles / DurationMinutes + per-tariff prices (T1 weekday, T2 night/weekend, T3 christmas), confidence scoring (high/medium/low via usage + CV) | Pipeline created 5,404 bidirectional routes (676 loaded into cache at high/medium confidence) |
| Apr 14 | Quote fast path -- tariff selection | Single AverageFare regardless of time-of-day | Weekday 07:00-22:00 -> T1, otherwise T2; 5+ pax auto +50% surcharge | Verified via Tariff 2 Night Rate response (SP7 9DQ -> SP8 4RE at 01:14) |

## Quote Latency Benchmark (Apr 14)

**Test route: SP7 9DQ -> SP8 4RE** (728 historical trips, high-confidence cache entry)

| Call # | Server-side latency | Path |
|--------|--------------------:|------|
| 1 (cold, JIT + tenant resolve) | 93ms | cache HIT |
| 2 (warm) | 6ms | cache HIT |
| 3 (warm) | 6ms | cache HIT |
| 4 (warm) | **1.9ms** | cache HIT |
| 5 (warm) | **1.5ms** | cache HIT |

Previous slow path (Google Distance Matrix x3-4 calls): 84-107ms.
Speedup: **~50-100x** for cached routes.
Coverage: 676 high/medium-confidence routes in cache -- covers the most common historical journeys.

## Final Benchmark (Apr 13)

**20 test queries -- all resolve correctly via intelligence (0 external API calls)**

| Metric | Value |
|--------|-------|
| Auto-resolved | 13 / 20 |
| Ask which (disambiguation) | 1 / 20 |
| Ask location (area clarification) | 3 / 20 |
| Mishearing-corrected | 4 / 20 |
| External API calls | 0 |
| Median response time | 1ms |
| AssemblyAI benchmark confidence | 94.8% (test call) |

## Architecture Summary

```
Caller speaks address
  -> ElevenLabs STT (primary) + ASR keyword bias (600 focused terms)
  -> Agent calls lookup_address tool
  -> Tier 1: POI hot list (230 keys, 61 locations, 62% coverage) -- O(1)
  -> Tier 2: In-memory canonical scan (~4,579 locations) -- ~0.01ms
  -> Tier 3: V2 API with trigram indexes (DB fallback) -- ~2ms
  -> If confirmed mishearing: SttComparisonService adds alias automatically
```
