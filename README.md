# Hivemind Skill

A Claude Code plugin and CLI for [Hivemind](https://hivemind.myosin.xyz) — Myosin's RAG-powered marketing AI. Lets agents (and humans) call the Chat, Knowledge Search, and Projects APIs.

- **Chat API** — consult Hivemind's AI personas (ghostwriter, strategist, GTM architect, general assistant)
- **Knowledge API** — semantic search over a curated marketing knowledge base with persona filtering, metadata boosting, and LLM reranking
- **Projects API** — create, poll, and update Hivemind projects to attach as context

## Install as a Claude Code Plugin (Recommended)

Inside Claude Code:

```
/plugin marketplace add Myosin-xyz/hivemind-skill
/plugin install hivemind@hivemind
```

That's it — Claude now auto-invokes the skill whenever you ask for marketing copy, brand strategy, go-to-market planning, knowledge lookups, or similar.

Before first use, create the credentials file:

```bash
mkdir -p ~/.config/hivemind
cat > ~/.config/hivemind/env <<'EOF'
HIVEMIND_API_KEY=hm_k_your_key_here
HIVEMIND_PROJECT_ID=
EOF
chmod 600 ~/.config/hivemind/env
```

Don't have a key? Request one at **[https://myosin.typeform.com/api-request](https://myosin.typeform.com/api-request)** — turnaround is typically one business day.

To update later: `/plugin update hivemind`. To remove: `/plugin uninstall hivemind`.

## Install as Standalone CLI (Optional)

If you also want to call the APIs from a terminal, cron job, or non-Claude script:

```bash
git clone https://github.com/Myosin-xyz/hivemind-skill.git
cd hivemind-skill
./install.sh
```

The installer copies `hivemind`, `hivemind-search`, and `hivemind-project` into `~/.local/bin/` and scaffolds `~/.config/hivemind/env`. Plugin users don't need this step — Claude invokes the scripts from inside the plugin.

See [SETUP.md](SETUP.md) for the detailed walkthrough, dependency list, and troubleshooting.

## Usage

```bash
# Chat — auto-classifies intent and picks a persona
hivemind chat "Write 3 headlines for a B2B SaaS landing page targeting CTOs"

# Force a persona
hivemind chat --persona ghostwriter "Draft a Twitter thread about our partnership"
hivemind chat --persona strategist "Analyze positioning against Vercel and Netlify"
hivemind chat --persona gtm        "Build a Q2 launch plan for a new API product"

# Stream tokens as they arrive
hivemind chat --stream "Give me a go-to-market plan for a B2B SaaS product"

# Knowledge search — RAG without the LLM layer
hivemind-search --threshold 0.5 --max 10 "product launch best practices"
hivemind-search --persona genius-strategist --rerank "competitive positioning frameworks"

# Projects — create, poll, update
hivemind-project create --url https://example.com --name "My Project"
hivemind-project get <project-id>
hivemind-project update <project-id> --stage growth --audiences "developers,enterprise"
```

Run any command with `--help` for full flag reference.

## Requirements

- `bash` 4+
- `curl`
- `jq`

## Repository Layout

```
hivemind-skill/
├── .claude-plugin/
│   ├── plugin.json                 Plugin manifest (id, version, author)
│   └── marketplace.json            Marketplace entry so /plugin can add this repo
├── README.md                       This file
├── SETUP.md                        Detailed setup + API key request
├── LICENSE                         MIT
├── install.sh                      Optional standalone-CLI installer
├── config/
│   └── env.example                 Template credentials file
└── skills/
    └── hivemind/                   The skill Claude loads
        ├── SKILL.md                Skill definition with YAML frontmatter
        ├── references/             On-demand reference docs
        │   ├── api-reference.md    Full API spec
        │   ├── personas.md         Persona decision guide
        │   ├── errors.md           Error codes + remediation
        │   └── examples.md         End-to-end examples
        └── scripts/                Bash tools (invoked via ${CLAUDE_PLUGIN_ROOT})
            ├── hivemind            Chat CLI
            ├── hivemind-search     Knowledge search CLI
            └── hivemind-project    Projects API CLI
```

## Security

- API keys live only in `~/.config/hivemind/env` (mode 600)
- The installer never writes keys to stdout or logs
- `.gitignore` excludes `config/env` and common `.env*` patterns
- Scripts read keys from the env file, never from arguments

If you accidentally commit a key, rotate it immediately: request a replacement via the typeform and ask a Hivemind admin to revoke the old one.

## License

MIT — see [LICENSE](LICENSE).

## Links

- [Request an API key](https://myosin.typeform.com/api-request)
- [Hivemind app](https://hivemind.myosin.xyz)
- [Upstream API docs](https://github.com/Myosin-xyz/hive-mind/blob/staging/documentation/API.md)
- [Claude Code plugin docs](https://code.claude.com/docs/en/plugins.md)
