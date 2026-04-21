# Persona Guide

Hivemind has four personas. Pick by the shape of what the user is asking for, not just the topic. A single topic (e.g. "product launch") can fit any of the three specialists depending on whether the user wants a plan, a position, or the copy.

## Quick Decision Tree

```
User's request contains...
├── "write" / "draft" / "rewrite" / "copy" / "headline" / "tagline" / "CTA"
│   → ghostwriter
├── "analyze" / "position" / "compare" / "framework" / "messaging" / "value prop"
│   → genius-strategist
├── "plan" / "launch" / "campaign" / "roadmap" / "funnel" / "channel strategy"
│   → gtm-architect
├── Multi-step (strategy → copy)
│   → genius-strategist first, feed output into ghostwriter
└── Unsure / doesn't fit above
    → omit --persona (auto-classify) OR general-assistant
```

## Personas in Detail

### `ghostwriter` (CLI: `ghostwriter`)

**Writes production-ready marketing copy.** Optimizes for clarity, voice, and conversion.

Strong at:
- Landing page headlines, subheadlines, hero copy
- Feature/benefit blocks
- CTA buttons, microcopy
- Twitter/LinkedIn threads, ad copy (Google, Meta, LinkedIn)
- Email sequences (cold outreach, nurture, onboarding, transactional)
- Product descriptions, marketplace listings
- One-liners, taglines, naming

Ask for:
- Multiple variants (3–5 options is the sweet spot)
- Format specs (char counts for ads, word counts for headlines)
- Tone guidance ("punchy", "authoritative", "playful without being silly")

Not for: strategy, positioning decisions, launch planning (use the other personas first, then pass results to ghostwriter for the copy).

### `genius-strategist` (CLI: `strategist`)

**Thinks in frameworks.** Brand positioning, competitive analysis, audience work, messaging architecture.

Strong at:
- Positioning statements and positioning-against-competitors
- Value proposition ladders
- Jobs-to-be-done / ICP definition
- Competitive matrices and differentiation
- Messaging frameworks (e.g. pain → promise → proof)
- Category design, narrative strategy

Ask for:
- Explicit frameworks ("use the April Dunford positioning approach")
- Assumptions it's making, so you can correct them
- Tradeoffs between options rather than a single answer

Not for: tactical execution or finished copy. Strategist outputs are inputs to GTM or ghostwriter.

### `gtm-architect` (CLI: `gtm`)

**Plans the execution.** Launch calendars, channel mixes, funnel design, budget frameworks.

Strong at:
- Launch plans (pre-launch, launch week, post-launch)
- Channel strategy and prioritization
- Campaign calendars across a quarter
- Funnel design (TOFU/MOFU/BOFU)
- Budget allocation and KPI targets
- Content roadmaps

Ask for:
- Time-boxed plans (30/60/90 days, Q2, launch week)
- Owners/roles even if hypothetical
- KPI targets per stage with rough benchmarks
- What to skip, not just what to do

Not for: writing the actual copy or positioning the brand — it'll gesture at both but they aren't its strengths.

### `general-assistant` (CLI: `general`)

Catch-all when the request doesn't clearly fit the three specialists. Fine for research-style questions, meta-questions about marketing itself, or prep work.

Often better to just **omit `--persona`** and let the API's intent classifier pick.

## Multi-Persona Workflows

Hivemind's three specialists compose. Chain them for complex tasks:

**Positioning + copy:**
```bash
STRAT=$(hivemind chat --persona strategist "Define positioning for [product]. Target: [ICP]. Competitors: X, Y, Z.")

echo "Positioning:
$STRAT

Now write a landing page hero (H1, subhead, CTA) using this positioning." | hivemind chat --persona ghostwriter
```

**Strategy + launch plan + copy:**
```bash
# 1. Positioning
POSITIONING=$(hivemind chat --persona strategist "...")

# 2. Launch plan grounded in positioning
PLAN=$(printf "Positioning:\n%s\n\nBuild a 30-day launch plan." "$POSITIONING" | hivemind chat --persona gtm)

# 3. Copy for the launch day assets
printf "Positioning:\n%s\n\nLaunch plan:\n%s\n\nWrite launch-day tweet, LinkedIn post, and email subject line." "$POSITIONING" "$PLAN" | hivemind chat --persona ghostwriter
```

## Prompt Archetypes

Paste-ready templates. Fill the bracketed fields before sending.

### Ghostwriter — Landing page hero

```
Product: [what it does in one line]
Audience: [ICP, including role + company size]
Current state: [existing hero copy, or "new product — no existing copy"]
Problem: [why existing copy isn't converting, if applicable]
Need:
  - 3 H1 options (max 10 words each)
  - 3 matching subheads (max 20 words each)
  - 2 CTA button options (max 3 words each)
Tone: [e.g. confident, technical, no jargon]
Constraints: [must mention X / must avoid Y]
```

### Strategist — Competitive positioning

```
Product: [what it does]
Target ICP: [role, company size, industry, trigger event]
Top 3 competitors: [A, B, C]
Current positioning: [one-liner, or "undefined"]
Need:
  - Positioning statement in the format "For [ICP], [product] is the [category] that [unique value] because [proof]"
  - 3 alternative angles with tradeoffs
  - Top 3 attack surfaces vs competitors
Constraints: [must be legally defensible / must not rely on X]
```

### GTM Architect — Launch plan

```
Product: [what it does]
Launch date: [absolute date]
Audience: [ICP]
Existing assets: [landing page / waitlist / beta users / nothing]
Budget: [rough dollar range, or "bootstrap"]
Team: [who's available, e.g. "1 founder + 1 part-time designer"]
Need:
  - T-minus-30 through T+30 day-by-day plan
  - Channel prioritization with reasoning
  - 3 KPIs with target numbers
  - Top 3 risks + mitigation
Constraints: [paid only if ROAS > X / no paid at all / must include LinkedIn]
```

## When to Pipe vs Inline

- **Inline** (quoted argument): 1–3 sentences, quick experiments, shell history value.
- **Piped stdin**: anything with structure (lists, headings, pasted context). Easier to edit and version.
- **Heredoc in a shell script**: repeatable prompts you run more than twice.

The API accepts up to 8000 chars of `text`. Above that you'll get `text_too_long` (400) — summarize or split.
