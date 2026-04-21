---
name: hivemind
description: Use when the user needs marketing copy, brand strategy, go-to-market plans, competitive analysis, launch plans, landing page text, ad copy, taglines, headlines, or any marketing/positioning work. Also use when searching a curated marketing knowledge base, or when creating/updating Hivemind projects. Triggers on words like "hivemind", "marketing", "copy", "headline", "positioning", "launch plan", "GTM", "brand", "campaign", "tagline", "CTA".
---

# Hivemind

Hivemind is a RAG-powered marketing AI with four specialist personas and a curated knowledge base. This skill exposes three APIs:

- **Chat** (`hivemind`) — send a prompt to a persona, get a response. Most common use.
- **Knowledge search** (`hivemind-search`) — RAG retrieval without the LLM layer.
- **Projects** (`hivemind-project`) — create/poll/update projects used as chat context.

All three scripts auto-load credentials from `~/.config/hivemind/env` (chmod 600). Never echo or log API keys.

> **Heads up: project auto-scoping.** If `HIVEMIND_PROJECT_ID` is set in the env file, every `hivemind chat` and `hivemind-search` call attaches it by default, which can cause personas to refuse prompts that don't match the project's scope. Pass `--no-project` on an individual call to bypass the env default, or `--project <uuid>` to switch to a different project for that call. Project scope only affects chat context — `hivemind-search` corpus is global regardless.

## Script paths

The scripts live inside this plugin. Invoke them at:

| Tool | Path |
|---|---|
| `hivemind` | `${CLAUDE_PLUGIN_ROOT}/skills/hivemind/scripts/hivemind` |
| `hivemind-search` | `${CLAUDE_PLUGIN_ROOT}/skills/hivemind/scripts/hivemind-search` |
| `hivemind-project` | `${CLAUDE_PLUGIN_ROOT}/skills/hivemind/scripts/hivemind-project` |

Claude substitutes `${CLAUDE_PLUGIN_ROOT}` at runtime. Examples below use short names (`hivemind`, `hivemind-search`, `hivemind-project`) for readability — expand to the full path when actually invoking. If the user also installed the CLIs on their `PATH` (via the repo's `install.sh`), the short names work directly in a terminal.

## Picking a Persona

| Persona | CLI alias | Use for |
|---|---|---|
| `ghostwriter` | `ghostwriter` | Writing copy: headlines, CTAs, taglines, landing pages, ad copy, emails, onboarding text, product descriptions |
| `genius-strategist` | `strategist` | Strategy: positioning, market analysis, competitive intel, messaging frameworks, value propositions, audience segmentation |
| `gtm-architect` | `gtm` | Tactics: launch plans, channel strategy, campaign calendars, funnels, budget allocation, KPI frameworks |
| `general-assistant` | `general` | General marketing questions that don't fit the other three |

**Decision rules:**
- "Write / draft / rewrite ..." → `ghostwriter`
- "Analyze / evaluate / position / compare ..." → `strategist`
- "Plan / launch / campaign / roadmap ..." → `gtm`
- Multi-step work (e.g., positioning + copy): call `strategist` first, then feed its output into `ghostwriter`.
- If you're unsure, omit `--persona` — the API auto-classifies intent.

For the full decision tree, see [references/personas.md](references/personas.md).

## Chat — Primary Workflow

```bash
# Auto-classify persona
hivemind chat "Write 3 headlines for a B2B SaaS landing page targeting CTOs"

# Force persona
hivemind chat --persona ghostwriter "Draft a Twitter thread about our launch"
hivemind chat --persona strategist "Analyze positioning vs Vercel and Netlify"
hivemind chat --persona gtm        "Build a Q2 launch plan for an API product"

# Attach a project for extra context (pulls social + intel reports server-side)
hivemind chat --persona strategist --project <uuid> "How should we respond to the competitor launch?"

# Bypass the default project from HIVEMIND_PROJECT_ID for one call
hivemind chat --no-project --persona ghostwriter "Unscoped copy request"

# Pipe long prompts via stdin (max 8000 chars)
cat brief.md | hivemind chat --persona ghostwriter

# Stream tokens for long outputs
hivemind chat --stream --persona gtm "Give me a full 90-day launch runbook"

# Full JSON including sources
hivemind chat --persona strategist --json "What positioning framework works for dev tools?"
```

**Conversations (persistent context):** only needed when you want Hivemind to remember prior turns across CLI invocations. Requires a user-attributed key and `--project`. See [references/examples.md](references/examples.md#conversations).

## Prompt Best Practices

Give Hivemind full context — it performs materially better with structured input than with one-liners:

1. **Product context** — what it does, who it's for, pricing tier
2. **Current state** — what exists now (copy, strategy, plan) so it can improve rather than start from scratch
3. **The problem** — why current isn't working (data if available)
4. **Deliverables** — explicit list with format/length requirements
5. **Audience** — who will see this, what they already know, where they come from
6. **Constraints** — tone, voice, length, brand guidelines, budget, timeline, must-haves/must-avoids

Pipe long briefs via stdin rather than cramming into a single argument.

## Knowledge Search

Use when you want source-grounded snippets without an LLM rewrite — e.g. "what does Hivemind's knowledge base say about ICP definition?".

```bash
# Simple
hivemind-search "product launch best practices"

# Persona-targeted (2-pass retrieval) + higher threshold
hivemind-search --persona strategist --threshold 0.5 --max 15 "competitive positioning frameworks"

# Full JSON (chunks with metadata)
hivemind-search --json "email subject line openings" | jq
```

Key flags (see `hivemind-search --help` for all):
- `--threshold 0.0-1.0` — relevance cutoff (0.4 default; raise for tighter matches)
- `--max 1-25` — result count cap
- `--persona ID` — enables persona-specific 2-pass ranking
- `--no-rerank` — skip LLM reranking (faster, cheaper, lower quality)

Knowledge search is **not** filtered by `--project` — the corpus is global. `--project` only gates endpoint access for project-scoped keys.

## Projects

Projects are containers for company context that Hivemind pulls into chat prompts (social media reports, intelligence reports). Create once, reuse via `--project <id>`.

```bash
# Create — returns immediately, enrichment runs async in the background
hivemind-project create \
  --url https://example.com \
  --name "My Project" \
  --description "A SaaS platform for..." \
  --stage launch \
  --type "SaaS,AI / ML"

# Poll until enrichment completes (or fails)
hivemind-project wait <project-id>

# Fetch current state
hivemind-project get <project-id>

# Patch fields (strict schema — unknown fields return 400)
hivemind-project update <project-id> \
  --stage growth \
  --audiences "developers,enterprise"

# Clear a field
hivemind-project update <project-id> --clear legal_considerations
hivemind-project update <project-id> --clear-list audiences
```

Creating / updating projects requires a **user-attributed** API key. Unattributed (legacy) keys can only `get`.

## Handling Errors

All three CLIs exit non-zero on failure and print the error code + message to stderr. Common cases:

| Error | Meaning | What to do |
|---|---|---|
| `invalid_key` / `missing_api_key` | Key wrong or missing | Check `~/.config/hivemind/env`; request a new key if revoked |
| `rate_limited` (429) | Per-minute window exceeded | Wait `Retry-After` seconds (printed in response) |
| `monthly_quota_exceeded` (429) | Monthly cap hit | Wait for 1st-of-month reset or request a cap increase |
| `project_access_denied` (403) | Key isn't attributed to the project's owner | Verify the right key/project pairing |
| `validation_error` (400) | Bad input | Read the `details` array; each entry names the field + reason |
| `text_too_long` (400) | Prompt > 8000 chars | Shorten or summarize; split into multiple requests |

Full error reference: [references/errors.md](references/errors.md).

## Quota Awareness

Default monthly caps per key: 100 chat, 200 search, 10 project creates, 50 project updates. If you're running multiple agents against the same key, note that every successful call consumes a quota unit — keep usage intentional.

## References

- [references/api-reference.md](references/api-reference.md) — full request/response schemas, headers, streaming protocol
- [references/personas.md](references/personas.md) — extended persona guide + prompt archetypes
- [references/errors.md](references/errors.md) — every error code with remediation
- [references/examples.md](references/examples.md) — end-to-end workflows (multi-step, streaming parser, project + chat)

## Requesting an API Key

Users without a key should fill out the request form:

**https://myosin.typeform.com/api-request**

Approval is typically one business day. Keys are shown only once — save immediately.
