# Error Reference

All Hivemind endpoints return structured errors. The CLIs print them to stderr and exit with code 2. This document lists every documented error, what it means, and how to resolve it.

## Error shape

Most errors follow one of two shapes. The Knowledge and Projects APIs use the nested form:

```json
{
  "success": false,
  "error": {
    "code": "validation_error",
    "message": "Human-readable message",
    "details": [
      { "field": "relevanceThreshold", "code": "invalid_relevance_threshold",
        "message": "...", "received": "2.5" }
    ]
  }
}
```

The Chat API uses a flatter form:

```json
{ "error": "missing_api_key", "message": "Missing x-api-key header" }
```

Always check the HTTP status code first — it narrows the class of error.

---

## Knowledge API (`POST /api/knowledge/search`)

| Status | Code | Meaning | Action |
|---|---|---|---|
| 400 | `validation_error` | One or more params invalid | Inspect `details[]` for the offending field |
| 401 | `invalid_api_key` | Missing, invalid, revoked, or expired key | Verify the key; request a new one if needed |
| 403 | `project_access_denied` | Key lacks access to the referenced project | Use a key attributed to the project owner |
| 429 | `rate_limited` | Per-minute limit hit | Wait `Retry-After` seconds |
| 429 | `monthly_quota_exceeded` | Monthly cap hit | Wait for the 1st UTC, or request a cap increase |
| 500 | `internal_error` | Server bug | Retry; contact support if persistent |

Common validation sub-codes:

| Field code | Fix |
|---|---|
| `missing_query` | `query` is empty after sanitization — provide non-empty content |
| `invalid_relevance_threshold` | Use 0–1 inclusive |
| `invalid_max_results` | Use 1–25 |
| `invalid_persona` | Use one of the four valid persona IDs |

---

## Chat API (`POST /api/v1/chat`)

| Status | Code | Meaning | Action |
|---|---|---|---|
| 400 | `invalid_json` | Body isn't valid JSON object | Send a valid JSON object |
| 400 | `missing_text` | `text` missing or empty | Provide a non-empty `text` |
| 400 | `text_too_long` | `text` > 8000 chars | Shorten or split |
| 400 | `invalid_stream` | `stream` not a boolean | Pass `true`/`false` |
| 400 | `invalid_persona` | Unknown persona ID | Use a valid ID |
| 400 | `invalid_project_id` | Not a valid UUID | Pass a proper UUID |
| 400 | `invalid_conversation_id` | Not a valid UUID | Pass a proper UUID |
| 400 | `invalid_request` | Mode collision or missing requirement | See below |
| 401 | `missing_api_key` | No `x-api-key` header | Add it |
| 401 | `invalid_key_format` | Malformed key | Check for truncation/whitespace |
| 401 | `invalid_key` | Key not found | Verify; request a new one |
| 401 | `revoked` | Key revoked by admin | Contact admin or request a new key |
| 401 | `expired` | Key past expiration | Request a new key |
| 403 | `project_access_denied` | Key lacks project scope, conversation not found, or not user-attributed | Use a user-attributed key with matching scope |
| 429 | `rate_limited` | Per-minute hit | Wait `Retry-After` |
| 429 | `monthly_quota_exceeded` | Monthly cap hit | Wait to reset or ask for higher cap |
| 499 | `request_cancelled` | Client closed connection | N/A (client-side) |
| 500 | `llm_error` | LLM provider failed or returned empty | Retry; contact support if persistent |
| 500 | `database_error` | DB lookup failed | Retry |
| 500 | `database_not_configured` | DB connection not configured | Contact admin |
| 500 | `internal_error` | Unexpected | Retry; contact support |

`invalid_request` fires in three cases:

1. Both `startConversation` and `conversationId` supplied.
2. `startConversation: true` without `projectId`.
3. Append mode with a `projectId` that doesn't match the conversation's project.

---

## Projects API (`/api/v1/projects`)

| Status | Code | Meaning | Action |
|---|---|---|---|
| 400 | `validation_error` | Body params invalid | Check `details[]` |
| 400 | `invalid_id` | Project ID isn't a valid UUID | Fix the URL |
| 400 | `unknown_fields` | System-managed field in body | Remove `id`, `user_id`, `created_at`, `enrichment_status`, etc. |
| 400 | `invalid_json` | Bad body | Send valid JSON |
| 403 | `user_attribution_required` | Key has no owning user | Ask admin to attribute it |
| 403 | `project_access_denied` | No scope for this project | Use the owning user's key |
| 409 | `website_url_conflict` | Another project in scope uses this URL | Use the `existing_project_id` in the error, or pick a different URL |
| 429 | `monthly_quota_exceeded` | Create/update cap hit | Wait to reset or ask for higher cap |

---

## Retry Strategy

| Error class | Retry? | How |
|---|---|---|
| 4xx validation / auth | No | Fix the request, don't retry blindly |
| 429 `rate_limited` | Yes | Sleep `Retry-After` seconds, then retry once |
| 429 `monthly_quota_exceeded` | No | Wait for month reset or request cap increase |
| 5xx `llm_error` / `database_error` | Yes | Exponential backoff, max 3 attempts |
| 5xx `internal_error` | Yes, cautiously | One retry after 5s; escalate if persistent |
| Network timeout | Yes | Increase `--timeout`, then retry |

The bundled CLIs do **not** auto-retry. Wrap them in shell logic if you need retries — this keeps quota accounting predictable and avoids compounding costs on systemic failures.

---

## Rate-Limit Headers

Every successful response includes:

- `X-RateLimit-Remaining` — requests left in the current 1-minute window
- `X-RateLimit-Reset` — ISO-8601 timestamp when the window resets

When `monthly_quota_exceeded` returns, headers include:

- `Retry-After: <seconds-until-next-UTC-month>`

Check these proactively in high-volume automation to throttle before hitting 429.

---

## Request Cancellation (499)

Client closed the connection mid-stream. You'll see this if the user hit Ctrl-C or the shell terminated curl. Quota is not consumed for cancelled chat completions.
