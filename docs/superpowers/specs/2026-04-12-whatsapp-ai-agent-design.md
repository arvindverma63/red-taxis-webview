# PRD: WhatsApp AI Customer Service Agent

**Author:** Claude + Peter
**Date:** 2026-04-12
**Status:** Draft
**Branch:** `feature/whatsapp-ai-agent` (off `dev`)
**Depends on:** `feature-ai-agent` (voice agent + speech layer + tool endpoints) merged to `dev`

---

## 1. What we're building

A WhatsApp-based AI customer service agent for the **Red Taxi SaaS platform**. This is a platform-level feature that will work for every tenant, not just Ace Taxis. Each tenant gets their own WhatsApp AI agent that uses their own data (pricing, availability, bookings, addresses, POIs) via the existing multi-tenant tool endpoints.

**Iteration 1 (this PRD):** built and tested against the Ace Taxis tenant using their existing Twilio WhatsApp number and org credentials. The architecture is multi-tenant from day one (webhook takes `?org={orgId}`, tenant DB resolved via `ITenantDbResolver`), matching the pattern the voice agent already established.

When a customer sends a WhatsApp message to the tenant's number, the AI agent responds conversationally — quoting prices, looking up bookings, creating/amending/cancelling bookings, and resolving addresses — using the exact same tool endpoints the voice agent already uses.

The agent runs as the default responder (AI answers immediately). When the AI can't help or the customer asks for a human, the conversation transfers to an operator who picks it up in a live chat UI inside admin-v2. The operator types in the browser; the message goes out via Twilio WhatsApp.

## 2. Why

- Customers increasingly prefer WhatsApp over phone calls
- The voice agent's 10 tool endpoints already exist and are production-tested
- The system prompt, booking flow, and tool definitions carry over per-tenant
- Adding a text channel reuses 90% of the backend and gives every Red Taxi tenant a second customer touchpoint with minimal per-tenant configuration
- Multi-tenant from day one: each tenant's WhatsApp agent reads from their own database, uses their own pricing/availability/POIs, and lives behind their own Twilio number

## 3. Architecture

```
Customer sends WhatsApp to the tenant's Twilio number
(Ace iteration 1: +15559211080)
   |
   v
Twilio receives message, POSTs to webhook
   |
   v
POST /api/v2/whatsapp-agent/incoming?org={orgId}
   |
   +--> Is this conversation in "human takeover" mode?
   |      YES --> queue message for the human operator, push via Pusher
   |      NO  --> continue to AI
   |
   +--> Load conversation history from WhatsAppConversations table
   |
   +--> Build Claude API request:
   |      - system prompt (same as voice, minus speech-specific rules)
   |      - tool definitions (same 9 tools, adapted for text)
   |      - conversation history (user + assistant messages)
   |      - current user message
   |
   +--> Call Claude API with tool_use enabled
   |      |
   |      +--> If Claude requests a tool call:
   |      |      Execute via IMediator.Send (same handlers as voice)
   |      |      Feed result back to Claude
   |      |      Loop until Claude produces a text response
   |      |
   |      +--> If Claude requests "transfer_to_human":
   |             Set conversation.mode = "human"
   |             Notify admin via Pusher
   |             Reply to customer: "I'm connecting you with the office now"
   |
   +--> Send Claude's text response via Twilio WhatsApp
   |
   +--> Persist message + response to WhatsAppConversations table
   |
   +--> Push update to admin dashboard via Pusher
```

### Why Claude API directly (not ElevenLabs text mode)

ElevenLabs ConvAI is WebSocket-session-based. For WhatsApp (async message-by-message), we'd need to maintain a persistent WebSocket per conversation, handle reconnection, timeouts, and session state externally. That's more complex than a simple request-response agentic loop.

Claude API with `tool_use` is request-response: send history + message, get back text or tool calls, loop. No persistent connections. Conversation state lives in our DB, not in ElevenLabs' session memory. We control retries, timeouts, and the tool execution layer. Simpler, more reliable, and cheaper per message.

If we later want to use ElevenLabs for WhatsApp (e.g., for voice notes), we can add it as a second path. The tool endpoints don't change.

## 4. Message routing

Each tenant has their own Twilio number / Messaging Service. For Ace (iteration 1), that's `+15559211080`.

The tenant's Twilio number currently handles:
- **Outbound dispatch notifications** (booking allocated/cancelled/amended) — sent BY us TO drivers/customers
- **Inbound status callbacks** (delivery receipts) — handled at `/api/v2/delivery-status/whatsapp/twilio`

We add a third path:
- **Inbound customer messages** — handled at `/api/v2/whatsapp-agent/incoming?org={orgId}`

The `?org={orgId}` query parameter identifies the tenant, matching the pattern used by the voice agent TwiML endpoint and the existing WhatsApp dispatch webhook. Each tenant's Twilio Messaging Service is configured to point its incoming-message webhook at this URL with their own org ID.

Twilio's webhook configuration (per tenant):
- The **incoming message webhook** on the Messaging Service fires when a NEW message arrives from a customer (not a status callback). We set this to our new endpoint with the tenant's org ID.
- The existing **status callback URL** stays unchanged.

Distinguishing message types: Twilio's webhook payload includes `MessageSid`, `From`, `To`, `Body`, `NumMedia`, etc. Inbound customer messages have `SmsStatus=received`. Status callbacks have `SmsStatus=delivered/failed/sent`. Our new endpoint only processes `received` messages.

## 5. Database schema

New table in tenant DB: `WhatsAppConversations`

```sql
CREATE TABLE "WhatsAppConversations" (
    "Id" SERIAL PRIMARY KEY,
    "CustomerPhone" VARCHAR(20) NOT NULL,
    "CustomerName" VARCHAR(100),           -- learned from booking data or caller intro
    "Mode" VARCHAR(20) NOT NULL DEFAULT 'ai',  -- 'ai' | 'human' | 'closed'
    "AssignedOperatorId" INT NULL,          -- FK to Users when mode=human
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "UpdatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "LastMessageAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "MessageCount" INT NOT NULL DEFAULT 0,
    "AiMessageCount" INT NOT NULL DEFAULT 0,
    "HumanMessageCount" INT NOT NULL DEFAULT 0
);

CREATE TABLE "WhatsAppMessages" (
    "Id" SERIAL PRIMARY KEY,
    "ConversationId" INT NOT NULL REFERENCES "WhatsAppConversations"("Id"),
    "Direction" VARCHAR(10) NOT NULL,       -- 'inbound' | 'outbound'
    "Sender" VARCHAR(20) NOT NULL,          -- 'customer' | 'ai' | 'operator'
    "Body" TEXT NOT NULL,
    "TwilioMessageSid" VARCHAR(50),
    "ToolCalls" JSONB,                      -- tool name + args + result for AI messages
    "CreatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IX_WhatsAppConversations_Phone ON "WhatsAppConversations"("CustomerPhone");
CREATE INDEX IX_WhatsAppMessages_ConvId ON "WhatsAppMessages"("ConversationId");
```

Conversations are keyed by `CustomerPhone` — one conversation per customer phone number. If a customer texts again after a conversation is closed, a new conversation is opened.

Auto-close rule: conversations with no messages for 24 hours are set to `mode=closed` by a background job.

## 6. Claude API orchestration

New service: `WhatsAppAgentOrchestrator` in `RedTaxi.AI`

```
Input: customer phone, message text, org ID
Output: AI response text (or human-takeover signal)

Steps:
1. Resolve tenant DB via ITenantDbResolver (same as voice tools)
2. Find or create WhatsAppConversation by phone
3. If conversation.Mode == "human" → skip AI, queue for operator
4. Load last N messages from WhatsAppMessages (context window)
5. Build Claude API request:
   - model: claude-sonnet-4-6 (fast, cheap, tool_use capable)
   - system: adapted system prompt (text-specific, no *Spoken fields)
   - tools: same 9 tool definitions (get_quote, lookup_address, etc.)
   - messages: conversation history + current message
6. Call Claude API
7. If response has tool_use blocks:
   - Execute each tool via IMediator.Send (same handlers)
   - Feed tool results back to Claude
   - Repeat until Claude produces a text block
8. If response includes "transfer_to_human" tool call:
   - Set conversation.Mode = "human"
   - Push Pusher notification to admin
   - Return "I'm connecting you with the office. Someone will be with you shortly."
9. Save messages to WhatsAppMessages
10. Return the AI text response
```

### System prompt adaptation for text

The voice system prompt has rules about `*Spoken` fields and "how to speak on a voice call". For WhatsApp text, we need a variant that:
- Drops the speech-specific rules (no `*Spoken` field instructions, no "don't say postcodes")
- Adds text-specific rules (can use emoji sparingly, can send postcodes/booking IDs in text, shorter messages preferred)
- Keeps the core booking flow, tool calling rules, and guardrails
- Adds a `transfer_to_human` tool the agent can call when it needs to escalate

This variant lives alongside the voice prompt in `tuning/agent-config/system-prompt-whatsapp.md`.

### Tool adaptations

The 9 existing tool endpoints stay as-is. The orchestrator calls them via `IMediator.Send` directly (not HTTP), which is faster and doesn't go through the AI-agent auth filter. The tool DTOs are the same; for text we can use either raw fields or `*Spoken` fields — the LLM will format naturally for text.

New tool: `transfer_to_human` — a fake tool with no server-side endpoint. When Claude calls it, the orchestrator intercepts and switches the conversation mode.

## 7. Human takeover flow

```
AI: "I'm connecting you with the office. Someone will be with you shortly."
  |
  +--> conversation.Mode = "human"
  +--> Pusher event: tenant-{orgId} channel, "whatsapp-takeover" event
  |      payload: { conversationId, customerPhone, customerName, lastMessage, summary }
  |
  +--> Admin-v2 shows a notification badge on the WhatsApp nav item
  +--> Admin-v2 WhatsApp page shows the conversation with a "Take over" button
  |
  +--> Operator clicks "Take over":
  |      POST /api/v2/whatsapp-agent/conversations/{id}/assign
  |      Sets AssignedOperatorId = current user
  |
  +--> Operator types in the chat UI:
  |      POST /api/v2/whatsapp-agent/conversations/{id}/send
  |      Sends via Twilio WhatsApp, saves to WhatsAppMessages
  |
  +--> Customer replies:
  |      Twilio webhook fires -> same incoming endpoint
  |      conversation.Mode == "human" -> skip AI, push to admin via Pusher
  |
  +--> Operator clicks "Return to AI":
         Sets conversation.Mode = "ai"
         Next customer message goes to the AI agent
```

## 8. Admin-v2 page: `/whatsapp`

Route: `src/frontend/apps/admin-v2/app/(dashboard)/whatsapp/page.tsx`

### Dashboard cards (top row)
- **Messages today** — count of WhatsAppMessages created today
- **Active conversations** — count of WhatsAppConversations where mode != 'closed'
- **AI replies sent** — count where Sender = 'ai' today
- **Human takeovers** — count where mode changed to 'human' today
- **Connection status** — green dot if Twilio webhook is responding (health check)

### Conversation list (left panel)
- List of active conversations, sorted by LastMessageAt desc
- Each row: customer phone/name, last message preview, time, mode badge (AI/Human/Closed)
- Orange dot for "human" mode conversations awaiting operator pickup
- Click to open conversation detail

### Conversation detail (right panel)
- Chat bubble UI (customer messages left, AI/operator messages right)
- AI messages have a small robot icon; operator messages have their name
- Tool calls shown as collapsible detail blocks between messages
- At the bottom: text input + send button (only when mode=human and assigned to current operator)
- "Take over" button (when mode=ai, switches to human)
- "Return to AI" button (when mode=human, switches back)

### Recent activity feed (bottom or separate tab)
- Chronological log of: new conversations, takeovers, bookings created via AI, errors
- Filterable by date range

## 9. API endpoints

All under `/api/v2/whatsapp-agent/`:

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/incoming?org={orgId}` | Twilio webhook for inbound WhatsApp messages. Validates Twilio signature. Routes to AI or human queue. |
| GET | `/conversations` | List active conversations (for admin dashboard) |
| GET | `/conversations/{id}` | Full conversation detail with messages |
| POST | `/conversations/{id}/assign` | Operator takes over a conversation |
| POST | `/conversations/{id}/send` | Operator sends a message (mode=human only) |
| POST | `/conversations/{id}/return-to-ai` | Switch back to AI mode |
| GET | `/dashboard` | Aggregated stats: messages today, active convs, takeovers, etc. |

## 10. Implementation plan

### Phase 1: Backend (this PR)
1. EF migration: `WhatsAppConversations` + `WhatsAppMessages` tables
2. `WhatsAppAgentController` — incoming webhook + admin CRUD endpoints
3. `WhatsAppAgentOrchestrator` — Claude API agentic loop with tool execution
4. `WhatsAppConversationService` — find/create conversations, save messages, mode switching
5. Pusher events for real-time admin updates
6. `system-prompt-whatsapp.md` — text-adapted system prompt
7. Twilio Messaging Service webhook configuration

### Phase 2: Admin frontend (same PR or follow-up)
1. `/whatsapp` route in admin-v2
2. Dashboard cards with TanStack Query data fetching
3. Conversation list + detail with live Pusher updates
4. Chat UI with send capability
5. Takeover / return-to-AI buttons
6. Notification badge on nav item when human takeover is pending

### Phase 3: Polish (follow-up)
1. Auto-close stale conversations (24h background job)
2. Conversation search / filter in admin
3. Export conversation history
4. Rate limiting per customer phone
5. Message templates for common operator responses
6. Rich media support (images, location pins)

## 11. Claude API cost estimate

Using `claude-sonnet-4-6`:
- ~500 input tokens per message (system prompt cached + history + message)
- ~200 output tokens per response
- ~$0.003 per input, ~$0.015 per output per 1K tokens
- **~$0.005 per message exchange** (under 1p)
- At 100 messages/day: ~50p/day, ~£15/month

Prompt caching: the system prompt + tool definitions (~4K tokens) are identical across all messages and cacheable. With prompt caching the input cost drops by ~90% for the cached portion.

## 12. Multi-tenancy

The architecture is multi-tenant from day one:

- Webhook URL includes `?org={orgId}` — tenant resolved via `ITenantDbResolver` (same as voice agent)
- `WhatsAppConversations` + `WhatsAppMessages` tables live in each tenant's own database
- System prompt can be customised per tenant (future: store in TenantSettings, fall back to default)
- Claude API key is platform-level (shared across tenants), billed to Red Taxi SaaS
- Each tenant configures their own Twilio number/Messaging Service to point at the webhook with their org ID

**Iteration 1:** tested against the Ace Taxis tenant (`org_3BfMRNcpn9933cL6snGXJ7k1PAN`). Tenant-specific config (company name in the system prompt, operating area for locality filter, etc.) is read from `TenantSettings` at runtime.

**Iteration 2+:** per-tenant WhatsApp agent toggle in the SaaS admin, per-tenant system prompt customisation, per-tenant metering (WhatsApp AI messages as a billable metric alongside SMS and voice).

## 13. What we're explicitly NOT building

- Voice notes in WhatsApp (iteration 2 — would use ElevenLabs STT)
- Proactive outbound AI messages (AI only responds, never initiates)
- WhatsApp Business API features beyond basic messaging (no templates, no catalog)
- Payment collection via WhatsApp
- File/image processing in AI responses
- Per-tenant system prompt editor (iteration 2 — use TenantSettings)

## 14. Dependencies

- `feature-ai-agent` merged to `dev` (voice agent tools, speech layer, mishearing corrector) — DONE
- Anthropic API key (`ANTHROPIC_API_KEY` env var) — platform-level, shared across tenants
- Each tenant's Twilio Messaging Service webhook URL updated to point at the new endpoint with their org ID
- Pusher already configured in the codebase (tenant-scoped channels)
- EF migration applied to every tenant DB (the migration runner already handles this on startup)
