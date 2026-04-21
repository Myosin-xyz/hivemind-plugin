# Hivemind API Reference

Complete reference for the three external APIs. Source of truth: [`hive-mind/documentation/API.md`](https://github.com/Myosin-xyz/hive-mind/blob/staging/documentation/API.md). This copy is mirrored for offline use and may lag; check upstream for the latest.

- **Host:** `https://hivemind.myosin.xyz`
- **Auth:** all endpoints require `x-api-key: hm_k_...`
- **Rate limit:** 30 req/min (sliding window, per key)
- **Monthly caps:** 100 chat, 200 search, 10 create, 50 update (per key, resets 1st UTC)

---

## Knowledge API — `POST /api/knowledge/search`

RAG retrieval over a curated marketing knowledge base. Supports persona-targeted 2-pass retrieval, metadata-based boosting, and LLM reranking.

### Request body

| Parameter | Type | Required | Constraints | Default | Description |
|---|---|---|---|---|---|
| `query` | string | yes | 1–5000 chars | — | Search query. HTML stripped, control chars removed. |
| `relevanceThreshold` | number | yes | 0–1 | — | Minimum score (0 = any, 1 = exact). |
| `maxResults` | integer | yes | 1–25 | — | Result cap. |
| `personaId` | string | no | see personas | — | Enables 2-pass persona-targeted retrieval. |
| `intentFiltering` | boolean | no | — | `false` | Filter by doc type based on query intent. |
| `objectiveFiltering` | boolean | no | — | `false` | Filter by persona objectives. |
| `keyPersonaResults` | integer | no | 1–25, requires `personaId` | `8` | Max critical docs in pass 1. |
| `metadataBoosting` | boolean | no | — | `true` | Boost by metadata matching (runs server-side intent classification). |
| `reRanking` | boolean | no | — | `true` | LLM-based reranking. |
| `projectId` | string (UUID) | no | — | — | Gates endpoint access for scoped keys. **Does not filter results.** |

**Valid `personaId` values:** `ghostwriter`, `genius-strategist`, `gtm-architect`, `general-assistant`.

### Success response (200)

```json
{
  "success": true,
  "data": {
    "chunks": [
      {
        "title": "Product Launch Playbook",
        "author": "Marketing Team",
        "content": "Full chunk content...",
        "objective": "Initial Product Launch",
        "doc_type": "playbook",
        "audience": ["growth marketers", "agency strategists"],
        "geography": ["global"],
        "industry": ["saas"],
        "marketing_verticals": ["growth", "content"],
        "channels": ["twitter", "linkedin"],
        "score": 0.87
      }
    ],
    "total_results": 5,
    "query": "product launch marketing strategies",
    "personaId": "genius-strategist",
    "metrics": { "searchTime": 234, "relevanceScore": 0.82 }
  }
}
```

### Health check: `GET /api/knowledge/search`

No auth required. Returns `{ "status": "healthy", ... }`.

---

## Chat API — `POST /api/v1/chat`

Full Hivemind pipeline: intent classification → RAG retrieval → web search → social context → LLM generation. Supports JSON responses and SSE streaming.

### Request body

| Parameter | Type | Required | Constraints | Description |
|---|---|---|---|---|
| `text` | string | yes | 1–8000 chars | The user message. Alias: `query`. |
| `stream` | boolean | no | — | Enable SSE streaming. Alias: `streamResponse`. Default `false`. |
| `persona` | string | no | see personas | Force a persona (skips intent classification). |
| `projectId` | string (UUID) | no | must exist | Attach project context. |
| `startConversation` | boolean | no | requires `projectId` | Create a new persistent conversation. |
| `conversationId` | string (UUID) | no | must be API-created | Append to an existing conversation. |

**Conversation modes:**
- **Stateless** (default) — neither `startConversation` nor `conversationId`. No persistence.
- **Start** — `startConversation: true` + `projectId`. Returns `conversation_id` + `message_id`. Requires user-attributed key.
- **Append** — `conversationId: <uuid>`. Loads prior history. Requires user-attributed key. Conversation must be API-created (web-app conversations are not appendable).
- Providing both `startConversation` and `conversationId` returns 400.

**Quota accounting:** the monthly `chat` counter increments only after a successful outcome (LLM completion for stateless; successful persistence for conversation modes). A failed LLM call does not consume a quota unit.

### JSON response (`stream: false`) — 200

```json
{
  "status": "success",
  "data": {
    "response": "Here is a comprehensive strategy for...",
    "persona": { "id": "genius-strategist", "name": "Genius Strategist", "icon": "brain", "accentColor": "#8B5CF6" },
    "sources": [{ "title": "Product Launch Playbook", "author": "Marketing Team" }],
    "conversation_id": "uuid",
    "message_id": "uuid"
  }
}
```

`conversation_id` and `message_id` only appear when persistence succeeds.

### SSE stream response (`stream: true`) — 200

Uses the [Vercel AI SDK Data Stream Protocol](https://sdk.vercel.ai/docs/ai-sdk-ui/stream-protocol#data-stream-protocol). Content type: `text/plain; charset=utf-8`; header `X-Vercel-AI-Data-Stream: v1`.

Each frame is `<type>:<payload>\n`:

| Frame | Code | Payload |
|---|---|---|
| Persona metadata | `2:` | `[{"persona": {...}}]`. Sent first. |
| Content chunk | `0:` | JSON-encoded string. Concatenate for full response. |
| Final metadata | `2:` | `[{"sources":[...], "conversation_id":"...", "message_id":"..."}]`. After content. |
| Done | `d:` | `{"finishReason": "stop" \| "cancelled" \| "error"}`. Last frame. |

Raw example:

```
2:[{"persona":{"id":"genius-strategist","name":"Genius Strategist","icon":"brain","accentColor":"#8B5CF6"}}]
0:"Here is "
0:"a comprehensive "
0:"strategy for your product launch..."
2:[{"sources":[{"title":"Product Launch Playbook","author":"Marketing Team"}]}]
d:{"finishReason":"stop"}
```

### Health check: `GET /api/v1/chat`

No auth required. Returns `{ "status": "ok", "endpoint": "HiveMind Chat API (external)", "version": "v1" }`.

---

## Projects API — `/api/v1/projects`

Projects are context containers. Create once, reference via `projectId` in chat. Enrichment (website scrape + AI extraction + social scrape) runs asynchronously — POST returns 202 immediately and you poll until `enrichment_status` is `ready` or `failed`.

### `POST /api/v1/projects`

At least one of `website_url` or `description` is required.

| Field | Type | Constraints | Description |
|---|---|---|---|
| `website_url` | string | valid URL, conditional¹ | Normalized: host lowercased, `www.` stripped, trailing `/` removed, `http`→`https`. |
| `project_name` | string | min 1 | Display name. |
| `description` | string | 1–5000, conditional¹ | Description (used for enrichment when no URL). |
| `project_type` | string[] | 1–4 items, 2–50 chars | Categories. New values auto-created. |
| `stage` | string | `idea` \| `pre-launch` \| `launch` \| `growth` \| `scale` \| `n/a` | Lifecycle stage. |
| `chains` | string[] | max 10 | Blockchain networks. |
| `audiences` | string[] | max 5 | Target audiences. |
| `channels` | string[] | max 10 | Marketing channels. |
| `geographics` | string[] | max 5 | Target regions. |
| `objectives` | string[] | — | Goals. |
| `legal_considerations` | string | — | Legal/regulatory notes. |
| `social_handles` | object | `Record<string,string>` | e.g. `{"twitter":"@handle"}`. |

¹ At least one of `website_url` or `description`.

**Idempotency:** when `website_url` is supplied, POST is idempotent on the normalized URL within the key's scope. Duplicates return `200` with `already_existed: true` and no new row.

**Success (new): 202**. Headers: `X-Monthly-Usage`, `X-Monthly-Limit`, `X-Monthly-Remaining`, `X-Monthly-Reset`.

Enrichment pipeline (background):
1. Scrape website (Puppeteer) if URL given
2. Extract structured data via AI
3. Merge — **never overwrites caller-supplied fields**
4. Onboarding side-effects (tags, social scrape, intel reports)
5. Set `enrichment_status: ready` (or `failed`)

### `GET /api/v1/projects/:id`

Returns the current project state including `enrichment_status` (`enriching` \| `ready` \| `failed`).

### `PATCH /api/v1/projects/:id`

Same fields as POST (all optional), plus `context_report`. **Strict schema** — unknown or system fields (`id`, `user_id`, `created_at`, `enrichment_status`, …) return 400.

**Clearing fields:** send `null` (scalars) or `[]` (lists).

**URL collisions:** if the new normalized `website_url` matches another project in scope, returns 409 with `existing_project_id`.

Creating and updating require a user-attributed key.

---

## Project Scoping

API keys can be attributed to a user, which automatically scopes access to that user's projects.

- No `projectId` in request → check skipped.
- `projectId` present, key has access → proceed.
- `projectId` present, key denied → 403 `project_access_denied`.
- Legacy keys (no `user_id`, pre-scoping) → allowed everywhere for backwards compat.
- Attributed keys with zero projects → denied on any project-referencing request.

For `/api/knowledge/search`, `projectId` only gates *endpoint access*; results are not filtered by project. For `/api/v1/chat`, `projectId` pulls project-specific social + intel reports into the prompt.

---

## Rate Limiting

Per-minute sliding window (default 30/min). Successful responses include:

- `X-RateLimit-Remaining` — requests remaining in current window
- `X-RateLimit-Reset` — ISO timestamp when window resets

429 `rate_limited` responses also include `Retry-After: <seconds>`.

## Monthly Quotas

Separate from per-minute limits. Counters reset on the 1st of each UTC month.

| Endpoint | Default cap |
|---|---|
| `chat` | 100 |
| `knowledge_search` | 200 |
| `create_project` | 10 |
| `update_project` | 50 |

429 `monthly_quota_exceeded` responses include `limit`, `current_usage`, `reset_timestamp`, and `Retry-After` (seconds until the next UTC month).

---

## Header Reference (Quick)

| Header | Direction | Endpoints | Meaning |
|---|---|---|---|
| `x-api-key` | request | all | API key (required) |
| `Content-Type: application/json` | request | POST/PATCH | Request body type |
| `X-RateLimit-Remaining` | response | all successes | Per-minute budget remaining |
| `X-RateLimit-Reset` | response | all successes | ISO time until reset |
| `Retry-After` | response | 429 | Seconds until retryable |
| `X-Monthly-Usage` | response | chat/projects | Monthly calls used |
| `X-Monthly-Limit` | response | chat/projects | Monthly cap |
| `X-Monthly-Remaining` | response | chat/projects | Calls left |
| `X-Monthly-Reset` | response | chat/projects | Next reset (ISO) |
| `X-Vercel-AI-Data-Stream` | response | chat stream | Value `v1` confirms SSE protocol |

For SSE streams, HTTP headers are committed before the LLM stream starts, so `X-Monthly-*` reflects quota state at request time (may differ from the final count by 1).
