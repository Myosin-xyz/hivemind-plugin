# Hivemind Plugin

A Claude Code plugin, Codex plugin, and CLI for [Hivemind](https://myosin.xyz/hivemind) — Myosin's RAG-powered marketing AI. Lets agents (and humans) call the Chat, Knowledge Search, and Projects APIs.

- **Chat API** — consult Hivemind's AI personas (ghostwriter, strategist, GTM architect, general assistant)
- **Knowledge API** — semantic search over a curated marketing knowledge base with persona filtering, metadata boosting, and LLM reranking
- **Projects API** — create, poll, and update Hivemind projects to attach as context

## Install as a Claude Code Plugin

Inside Claude Code:

```
/plugin marketplace add Myosin-xyz/hivemind-plugin
/plugin install hivemind@hivemind
```

That's it, Claude now auto-invokes the skill whenever you ask for marketing copy, brand strategy, go-to-market planning, knowledge lookups, or similar.

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

## Install as a Codex Plugin

This repo also includes Codex plugin metadata in `skills/.codex-plugin/plugin.json` and Codex marketplace metadata in `.agents/plugins/marketplace.json`, using the same shared skill under `skills/hivemind/`.

Add the marketplace:

```bash
codex marketplace add Myosin-xyz/hivemind-plugin
```

For local development, use the local checkout instead:

```bash
codex marketplace add /path/to/hivemind-plugin
```

Then restart Codex, open Plugins, and install or enable **Hivemind** from the Hivemind marketplace. Codex does not currently expose a Claude-style `plugin install` CLI command; installation happens from the Codex Plugins UI after the marketplace is added.

The shared skill content is the same across Claude Code and Codex. If you only want the process instructions without plugin packaging, install the `skills/hivemind` skill from this repo as a skill-only setup.

Before first use, create the credentials file:

```bash
mkdir -p ~/.config/hivemind
cat > ~/.config/hivemind/env <<'EOF'
HIVEMIND_API_KEY=hm_k_your_key_here
HIVEMIND_PROJECT_ID=
EOF
chmod 600 ~/.config/hivemind/env
```

## Install as Standalone CLI (Optional)

If you also want to call the APIs from a terminal, cron job, or non-agent script:

```bash
git clone https://github.com/Myosin-xyz/hivemind-plugin.git
cd hivemind-plugin
./install.sh
```

The installer copies `hivemind`, `hivemind-search`, and `hivemind-project` into `~/.local/bin/` and scaffolds `~/.config/hivemind/env`. Plugin users don't need this step — Claude Code and Codex can invoke the shared scripts from inside the plugin checkout.

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
hivemind-plugin/
├── .agents/
│   └── plugins/
│       └── marketplace.json        Codex marketplace entry for codex marketplace add
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
    ├── .codex-plugin/
    │   └── plugin.json             Codex plugin manifest
    └── hivemind/                   The shared skill Claude Code and Codex load
        ├── SKILL.md                Skill definition with YAML frontmatter
        ├── references/             On-demand reference docs
        │   ├── api-reference.md    Full API spec
        │   ├── personas.md         Persona decision guide
        │   ├── errors.md           Error codes + remediation
        │   └── examples.md         End-to-end examples
        └── scripts/                Bash tools shared by Claude Code, Codex, and the standalone CLI
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
- [Hivemind app](https://myosin.xyz/hivemind)
- [API docs](https://hivemind.myosin.xyz/api-docs)
- [Plain-text API docs](https://hivemind.myosin.xyz/api-docs.md)
- [Claude Code plugin docs](https://code.claude.com/docs/en/plugins.md)
