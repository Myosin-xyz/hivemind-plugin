# End-to-End Examples

Copy-pastable recipes for real Hivemind workflows. Assumes the CLIs are on `$PATH` and `~/.config/hivemind/env` is configured.

## Contents

- [Basic chat](#basic-chat)
- [Streaming](#streaming)
- [Conversations](#conversations)
- [Project + chat](#project--chat)
- [Knowledge search](#knowledge-search)
- [Multi-step positioning → copy](#multi-step-positioning--copy)
- [Raw curl (no CLI)](#raw-curl-no-cli)
- [Streaming parser in JavaScript](#streaming-parser-in-javascript)

---

## Basic chat

```bash
# Auto-classify intent
hivemind chat "Write 3 headlines for a B2B SaaS landing page targeting CTOs"

# Force persona
hivemind chat --persona ghostwriter "Draft a LinkedIn post announcing our Series A"

# Piped brief
cat <<'EOF' | hivemind chat --persona ghostwriter
Product: Aurevon — AI-powered business automation for SMBs
Audience: non-technical SMB owners
Current headline: "Automate Your Business" (too generic, converts <1%)
Need:
  - 3 headline options (max 10 words)
  - 1 subhead per headline (max 20 words)
  - Focus on outcomes, not features
Tone: confident, plain-English, no jargon
EOF
```

## Streaming

```bash
# Stream plain text to stdout as tokens arrive
hivemind chat --stream --persona gtm "Give me a 90-day launch runbook for an API product"

# Fallback to synchronous JSON if streaming breaks mid-way
hivemind chat --json --persona gtm "Give me a 90-day launch runbook" | jq -r '.data.response'
```

## Conversations

Persistent conversations let Hivemind remember prior turns across CLI invocations. Requires a user-attributed key and `--project`.

```bash
PROJECT_ID="a1b2c3d4-e5f6-7890-abcd-ef1234567890"

# Turn 1 — start a new conversation, capture IDs
RESP=$(hivemind chat --json --project "$PROJECT_ID" --start-conversation \
  --persona strategist \
  "Define positioning against our top 3 competitors.")

CONVO_ID=$(echo "$RESP" | jq -r '.data.conversation_id')
echo "$RESP" | jq -r '.data.response'

# Turn 2 — append, Hivemind remembers turn 1
hivemind chat --project "$PROJECT_ID" --conversation-id "$CONVO_ID" \
  --persona strategist \
  "Now give me the one attack surface you'd prioritize and why."

# Turn 3 — same conversation, switch persona if useful
hivemind chat --project "$PROJECT_ID" --conversation-id "$CONVO_ID" \
  --persona ghostwriter \
  "Turn that into a 2-tweet thread."
```

Conversations created via the web app are **not** appendable through the API. Only conversations created via `--start-conversation`.

## Project + chat

Projects carry company context (social data, intel reports) into chat prompts.

```bash
# Create a project — returns immediately, enrichment runs in background
CREATE=$(hivemind-project create --json \
  --url https://myosin.xyz \
  --name "Myosin" \
  --description "Crypto marketing agency" \
  --stage growth \
  --type "Marketing,Agency")

PROJECT_ID=$(echo "$CREATE" | jq -r '.data.id')
echo "Project: $PROJECT_ID"

# Poll until enrichment finishes (or fails)
hivemind-project wait "$PROJECT_ID"

# Chat with project context
hivemind chat --project "$PROJECT_ID" --persona strategist \
  "Given our positioning and recent social activity, what's the next campaign we should run?"
```

## Knowledge search

Use when you want source-grounded snippets without LLM rewriting. Good for research, citation, or feeding into your own prompts.

```bash
# Simple
hivemind-search "ICP definition frameworks"

# Persona-targeted, higher threshold, full JSON
hivemind-search --persona strategist --threshold 0.6 --max 20 --json \
  "category design vs category creation" \
  | jq '.data.chunks[] | {title, score, content: (.content | .[0:200])}'

# Feed top hit into a chat prompt
TOP=$(hivemind-search --json --max 3 "email subject line best practices" \
  | jq -r '.data.chunks | map(.content) | join("\n\n---\n\n")')

printf "Knowledge snippets:\n%s\n\nUsing these, write 5 email subject lines for our launch announcement." "$TOP" \
  | hivemind chat --persona ghostwriter
```

## Multi-step positioning → copy

A common pattern: use the strategist to produce a positioning framework, then pass that output into ghostwriter for final copy.

```bash
#!/usr/bin/env bash
set -euo pipefail

BRIEF="Product: Rezerve — automated on-call scheduling for engineering teams
ICP: engineering managers at 50-500 person companies
Competitors: PagerDuty, Opsgenie, Grafana OnCall
Current positioning: none (pre-launch)"

echo "=== Positioning ==="
POSITIONING=$(echo "$BRIEF
Need:
- Positioning statement in April Dunford's format
- 3 alternative angles with tradeoffs
- Top 3 attack surfaces vs competitors" \
  | hivemind chat --persona strategist)

echo "$POSITIONING"

echo ""
echo "=== Landing page copy ==="
echo "$BRIEF

Positioning (use this):
$POSITIONING

Need:
- 3 H1 options (max 10 words)
- Matching subheads (max 20 words)
- 1 hero-section CTA
- 3 feature-block headlines (verb + outcome)" \
  | hivemind chat --persona ghostwriter
```

## Raw curl (no CLI)

If you need to call the API from a language without a wrapper.

```bash
API_KEY="hm_k_..."

curl -sS -X POST https://hivemind.myosin.xyz/api/v1/chat \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Write a launch tweet for a B2B dev tool",
    "stream": false,
    "persona": "ghostwriter"
  }' \
  | jq -r '.data.response'
```

Knowledge search:

```bash
curl -sS -X POST https://hivemind.myosin.xyz/api/knowledge/search \
  -H "x-api-key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "go-to-market launch strategies",
    "relevanceThreshold": 0.5,
    "maxResults": 10,
    "personaId": "gtm-architect",
    "reRanking": true
  }' \
  | jq '.data.chunks[] | {title, score}'
```

Projects — poll until ready:

```bash
PROJECT_ID="..."
while true; do
  STATUS=$(curl -sS "https://hivemind.myosin.xyz/api/v1/projects/$PROJECT_ID" \
    -H "x-api-key: $API_KEY" | jq -r '.data.enrichment_status')
  echo "status: $STATUS"
  case "$STATUS" in
    ready|failed) break ;;
  esac
  sleep 5
done
```

## Streaming parser in JavaScript

```js
const response = await fetch('https://hivemind.myosin.xyz/api/v1/chat', {
  method: 'POST',
  headers: {
    'x-api-key': process.env.HIVEMIND_API_KEY,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    text: 'Analyze the competitive landscape for marketing automation',
    stream: true,
  }),
});

const reader = response.body.getReader();
const decoder = new TextDecoder();
let fullText = '';
let sources = [];

while (true) {
  const { done, value } = await reader.read();
  if (done) break;

  const chunk = decoder.decode(value, { stream: true });
  for (const line of chunk.split('\n').filter(Boolean)) {
    const type = line[0];
    const payload = line.slice(2);

    if (type === '0') {
      const text = JSON.parse(payload);
      fullText += text;
      process.stdout.write(text);
    } else if (type === '2') {
      const frames = JSON.parse(payload);
      for (const f of frames) {
        if (f.sources) sources = f.sources;
      }
    } else if (type === 'd') {
      const { finishReason } = JSON.parse(payload);
      console.log(`\n[done: ${finishReason}]`);
    }
  }
}

console.log('\nSources:', sources);
```

## Quota and Rate-Limit Awareness

For automation touching the API frequently:

```bash
# Read remaining budget from response headers before making more calls
HEADERS=$(curl -sS -D - -o /dev/null "https://hivemind.myosin.xyz/api/v1/chat" \
  -X POST \
  -H "x-api-key: $HIVEMIND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"ping"}')

echo "$HEADERS" | grep -iE '^x-(ratelimit|monthly)-'
```

Output looks like:

```
x-ratelimit-remaining: 27
x-ratelimit-reset: 2026-04-21T15:01:00Z
x-monthly-usage: 42
x-monthly-limit: 100
x-monthly-remaining: 58
x-monthly-reset: 2026-05-01T00:00:00Z
```

Use `x-monthly-remaining` to throttle batch jobs before they hit 429.
