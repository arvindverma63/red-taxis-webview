# Intelligence-Powered Voice Agent

**Date:** 2026-04-12
**Status:** Design
**Branch:** `feature/journey-intelligence-pipeline`

## Context

The Journey Intelligence Pipeline has mined 18 months of booking data into 5 derived tables: 5,964 canonical locations, 1,198 aliases, 9,878 popular routes, 5,964 demand patterns, and 2,897 STT bias terms. None of this data is currently used by the voice agent. The agent still hits external APIs for every address lookup, uses 6 hand-coded mishearing rules, and treats every caller as a stranger.

This spec wires the intelligence data into the voice agent. Priority order: accuracy, speed, personality.

## Layer 1: Accuracy — IntelligenceLookup

### Problem

`lookup_address` calls DispatchSearch (Ideal Postcodes / Google Places) for every query. "Asda" returns multiple towns. "The station" is ambiguous. 6 regex rules in MishearingCorrector catch a fraction of ASR errors.

### Solution

A new service `IntelligenceLookup` that queries the intelligence tables before falling back to the external API.

**File:** `RedTaxi.AI/Intelligence/Services/IntelligenceLookup.cs`

```
Interface:
  Task<IntelligenceLookupResult> ResolveAsync(string query, CancellationToken ct)

Returns:
  - List<ResolvedCandidate> Candidates  (0-3 results)
  - string Source                        ("intelligence", "alias_correction", "fallback_api")
  - string? DisambiguationHint           ("auto_resolved", "ask_which", "airport")
  - bool IsAirport
  - bool AskTerminal
  - string? TerminalPrompt
```

### Lookup flow

**All queries use EF Core LINQ (parameterised). No raw SQL with string interpolation.**

```
1. Normalise query (AddressNormalizer.Normalize)
2. Try-catch the entire intelligence path (on any exception → fall through to DispatchSearch)
3. Search canonical locations via EF Core LINQ:
   db.Set<CanonicalLocation>()
     .Where(c => c.CanonicalName.ToLower().Contains(normalised))
     .OrderByDescending(c => c.TotalFrequency)
     .Take(5)
   Also search aliases:
   db.Set<LocationAlias>()
     .Where(a => a.NormalisedText.Contains(normalised))
     .Include(a => a.CanonicalLocation)
     .OrderByDescending(a => a.Frequency)
     .Take(5)
   Merge results, deduplicate by canonical ID, rank by TotalFrequency.
4. If 1+ results:
   a. Apply disambiguation rules (new logic — see matrix below):
      - Airport → always ask
      - Station → local default (Gillingham)
      - Supermarket → always ask
      - Hospital/Doctors → auto-resolve
      - 1 result with freq > 10x second → auto-resolve
      - 2-3 close results → ask_which
   b. Build ResolvedCandidate from canonical data (address, postcode, spoken name, type)
   c. Return with Source = "intelligence"
5. If 0 results from both searches:
   Fall through to DispatchSearch (existing external API path)
   Return with Source = "fallback_api"
```

**Future-proofing:** For datasets larger than ~10K canonical locations, add a `pg_trgm` GIN index on `CanonicalName` and `NormalisedText` columns to keep LIKE queries fast. At current scale (5,964 locations) a sequential scan is ~2ms which is fine.

### Wiring into AiAgentController

The existing `LookupAddressTool` method changes from:

```
Today:    MishearingCorrector → DispatchSearch → Resolve → Locality filter
Proposed: MishearingCorrector → IntelligenceLookup.ResolveAsync()
            ├─ HIT  → return intelligence result (no external API call)
            └─ MISS → DispatchSearch → Resolve → Locality filter (unchanged)
```

The controller injects `IIntelligenceLookup` alongside the existing services. The fast path adds ~2ms; the slow path is unchanged.

### Disambiguation rules (new business logic)

These rules were derived from Peter's operational knowledge of Ace Taxis' service area and confirmed during brainstorming. They are new logic — no existing code implements them.

| LocationType | Strategy | Rationale |
|---|---|---|
| airport | AlwaysAsk | Multiple airports in range. + terminal (Heathrow/Gatwick only) + bags |
| train_station | LocalDefault | 90%+ of "station" queries mean Gillingham. Confirm, don't ask. |
| supermarket | AlwaysAsk | Multiple locations (Tesco Shaftesbury vs Gillingham). Always clarify. |
| hospital | AutoResolve | Callers know their hospital. Don't ask. |
| doctors | AutoResolve | Callers know their GP. Don't ask. |
| pub | FrequencyRank | Top frequency wins if 3x+ gap, else ask. |
| hotel | FrequencyRank | Same as pub. |
| school | AutoResolve | Usually one per name. Caller will specify if wrong. |
| All others | FrequencyRank | Top frequency wins if dominant, else ask. |

**Locality postcodes** are extracted into a shared constant (`LocalPostcodePrefixes`) used by both IntelligenceLookup and the existing locality filter in LookupAddressTool. This avoids duplicating the list in two places. The values (`SP7, SP8, SP3, SP5, BA8, BA9, BA10, BA12, DT9, DT10, DT11`) will become tenant config when multi-tenancy needs it.

### Alias-powered correction

When the query matches an alias but not a canonical name, the alias acts as an automatic correction. Example:

- Caller says "Tescos Shaftesbury" (ASR hears "Tescos")
- No canonical match for "tescos shaftesbury"
- Alias table has: "Tescos Shaftesbury" → canonical "Tesco, Coppice Street, Shaftesbury" (freq: 12)
- Agent uses the canonical location directly

This replaces the need for hand-coded mishearing rules for any location that's been booked before. The 6 existing regex rules stay as a safety net for truly garbled speech that doesn't match any alias.

## Layer 2: Speed — Route Prediction + Cached Pricing

### Problem

Every quote hits the distance API (~800ms). The agent asks 6-8 questions per booking. Repeat callers answer the same questions every time.

### Solution A: Route-based instant pricing

**Change to `QuoteTool` in AiAgentController:**

Before calling `GetCashPrice` (live tariff + distance API), check `intelligence_popular_routes`:

```sql
SELECT AverageFare, UsageCount
FROM intelligence_popular_routes
WHERE PickupLocationId = @pickupId AND DestinationLocationId = @destId
```

If found AND `LastUsed` within last 90 days AND `UsageCount > 5`: return cached average fare with `source: "cached_estimate"`. The agent says "usually around twelve fifty" instantly.

If not found OR stale (> 90 days): fall through to live pricing (unchanged).

**Important:** Cached fares are estimates only. The system prompt instructs the agent to say "usually around" (not "that'll be exactly"). The live tariff is always used for the actual booking — the cached fare just gives a fast initial response.

### Solution B: Caller route shortcut (deferred to iteration 2)

Connecting caller phone numbers to canonical location IDs requires an additional pipeline step (normalise caller's past addresses → match to canonical via alias table → build caller-to-location mapping). This is not yet built.

**Deferred.** The existing CallerProfile enrichment from the Brain PRD (name, home address, frequent destinations) already provides basic repeat-caller support. The intelligence-backed version with top routes will be added in a follow-up iteration once the phone-to-canonical mapping pipeline exists.

### Speed impact

| Scenario | Today | After |
|---|---|---|
| Address lookup (known place) | 500-1500ms (API) | ~2ms (DB) |
| Address lookup (unknown place) | 500-1500ms (API) | 500-1500ms (unchanged) |
| Price quote (common route) | 800ms (distance API) | ~2ms (DB) |
| Repeat caller booking | 6-8 questions | 2-3 questions |

## Layer 3: Personality — Dynamic ASR + Time Awareness

### Dynamic ASR keyword generation

**New job:** `AiAgentKeywordRefreshJob`

Runs after each intelligence pipeline refresh. Reads the top-N STT bias terms from `intelligence_speech_bias_terms`, merges with a small static list of essential terms (terminal names, booking verbs, UK time phrases), and writes the result to a JSON structure matching the `agent.json` keywords array format.

The output replaces the 450 hand-curated keywords with ~500-800 frequency-weighted terms from real booking data.

**File:** `RedTaxi.AI/Intelligence/Jobs/AsrKeywordRefreshJob.cs`

**Output path:** `src/backend/RedTaxi.AI/tuning/agent-config/generated-keywords.json`

The existing `sync_agent.py` at `src/backend/RedTaxi.AI/tuning/sync_agent.py` will need a small modification to merge `generated-keywords.json` into the `agent.json` keywords array before pushing to ElevenLabs. This is a ~10-line change to the sync script.

### Time-aware context (lightweight)

No code change needed — just a system prompt addition. The `lookup_address` response already includes the canonical location's `LocationType`. The system prompt gains:

```
When a booking is for a station between 06:00-09:00 or 16:00-19:00,
the caller is likely a commuter — keep it brisk, skip small talk.

When a booking is for a pub or restaurant after 21:00,
the caller may have been drinking — be patient and clear.

When a booking is for an airport, always ask about early check-in times
and whether they need a return journey.
```

No demand pattern queries needed at this stage — just type + time heuristics in the prompt.

## Files to create/modify

### New files

| File | Purpose |
|---|---|
| `Intelligence/Services/IntelligenceLookup.cs` | Core lookup service — queries canonical + alias tables |
| `Intelligence/Jobs/AsrKeywordRefreshJob.cs` | Generates dynamic ASR keywords from STT bias terms |

### Modified files

| File | Change |
|---|---|
| `Controllers/AiAgentController.cs` | Wire IntelligenceLookup into LookupAddressTool, add route cache to QuoteTool, enrich LookupCallerBookings with top routes |
| `tuning/agent-config/system-prompt.md` | Add caller route shortcut instructions, time-aware phrasing, alias correction awareness |
| `Dtos/AiToolDtos.cs` | Add CallerTopRoute DTO, add Source field to LookupAddressToolResponse |
| `Program.cs` | Register IIntelligenceLookup in DI |

### Error handling

IntelligenceLookup wraps the entire intelligence query in try/catch. On any exception (DB connection failure, empty tables, query timeout), it logs a warning and returns an empty result, which triggers the existing DispatchSearch fallback. The voice agent never fails because the intelligence layer is down — it just loses the speed benefit.

### Unchanged

- MishearingCorrector — kept as safety net (6 regex rules stay)
- DispatchSearch — remains the fallback when intelligence has no match or throws
- All existing tool definitions — response shapes are backward-compatible (new fields are additive)

## Data flow summary

```
Caller speaks
  → ElevenLabs ASR (with dynamic keywords from intelligence)
  → Tool call: lookup_address("asda")
  → AiAgentController.LookupAddressTool
      → MishearingCorrector.TryCorrect (6 regex rules)
      → IntelligenceLookup.ResolveAsync
          → Search canonical locations (5,964 entries, ~2ms)
          → Search aliases if no direct match (1,198 entries)
          → Apply disambiguation matrix
          → HIT: return intelligence result
          → MISS: fall through to DispatchSearch (external API)
      → Return candidates to agent

Caller confirms pickup + destination
  → Tool call: get_quote(SP8 4PZ, SP7 8JU)
  → AiAgentController.QuoteTool
      → Check intelligence_popular_routes (9,878 entries, ~2ms)
      → HIT: return cached average fare
      → MISS: call GetCashPrice (live tariff + distance API)

Known caller rings
  → Tool call: lookup_caller_bookings(07xxx)
  → Response includes callerTopRoutes from intelligence
  → Agent offers: "Same as last time — home to Thorngrove?"
  → Caller says yes → skip to confirmation (2 questions instead of 8)
```

## Testing

- Unit tests for IntelligenceLookup: normalisation, canonical search, alias fallback, disambiguation
- Unit tests for AsrKeywordRefreshJob: output format, deduplication, weight ordering
- Integration test: full lookup flow against real database with known locations
- Voice test: call the agent, say "Asda", verify it returns the local one without external API

## Success criteria

1. **Accuracy:** "Asda" returns Asda Gillingham (not 3 towns). "The station" defaults to Gillingham Station. "Tescos" corrects to Tesco automatically.
2. **Speed:** Known-place lookups under 5ms. Common route quotes under 5ms. Repeat caller bookings in 2-3 questions.
3. **Personality:** Agent uses frequency-weighted ASR keywords. Adjusts tone for commuters vs nightlife. Recognises regulars and offers shortcuts.
