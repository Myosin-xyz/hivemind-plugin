# Setup

Three install paths. Pick the one that matches how you'll use Hivemind.

- **[Plugin install](#plugin-install)** — recommended for Claude Code users. Claude auto-invokes the skill; no PATH changes, no script copies.
- **[Codex plugin install](#codex-plugin-install)** — add the repo as a Codex marketplace, then install Hivemind from Codex's Plugins UI.
- **[Standalone CLI install](#standalone-cli-install)** — for humans using the CLIs from a terminal / cron / scripts outside agent runtimes. Optional even if you installed the plugin.

Both paths need the same credentials file at `~/.config/hivemind/env`.

---

## 1. Request an API Key

Hivemind API keys are issued on request. Fill out the form — the Myosin team reviews submissions and emails your key once approved.

**→ [https://myosin.typeform.com/api-request](https://myosin.typeform.com/api-request)**

The form asks for:
- Your name and email
- The application or use case you're building
- Expected request volume (for rate-limit sizing)

Turnaround is typically one business day. Keys look like `hm_k_<random>` and are **shown only once** — save yours to a password manager immediately.

### Default limits

Every key ships with:
- **30 requests / minute** (sliding window)
- **Monthly quotas** — 100 chat, 200 knowledge searches, 10 project creates, 50 project updates

Need more? Mention expected volume in the request form, or ask an admin once you're onboarded.

---

## 2. Install Dependencies

Both install paths need:

| Tool | Purpose | Install |
|---|---|---|
| `bash` 4+ | Shell | Pre-installed on macOS/Linux |
| `curl` | HTTP client | `apt install curl` / `brew install curl` |
| `jq` | JSON parsing | `apt install jq` / `brew install jq` |

Verify:

```bash
bash --version    # 4.0 or newer
curl --version
jq --version
```

---

## Plugin Install

Inside Claude Code:

```
/plugin marketplace add Myosin-xyz/hivemind-plugin
/plugin install hivemind@hivemind
```

Claude pulls the repo into its plugin cache, reads `.claude-plugin/plugin.json`, and registers the skill. From then on, any session where you mention marketing copy, positioning, go-to-market plans, or similar triggers will auto-invoke Hivemind.

### Configure credentials

Create the env file:

```bash
mkdir -p ~/.config/hivemind
cat > ~/.config/hivemind/env <<'EOF'
HIVEMIND_API_KEY=hm_k_your_key_here
HIVEMIND_PROJECT_ID=
EOF
chmod 600 ~/.config/hivemind/env
```

Paste your key where it says `hm_k_your_key_here`.

### Verify

In a fresh Claude Code session, ask:

> Write one landing page headline for a test product.

Claude should invoke the `hivemind` script via the plugin and return a headline. If instead it writes the headline itself without calling the skill, the plugin isn't loading — check that `/plugin list` shows `hivemind` as installed and restart Claude Code.

### Update and uninstall

```
/plugin update hivemind
/plugin uninstall hivemind
```

---

## Codex Plugin Install

This repo ships both Codex plugin metadata at `.codex-plugin/plugin.json` and Codex marketplace metadata at `.agents/plugins/marketplace.json`.

Add the marketplace:

```bash
codex plugin marketplace add Myosin-xyz/hivemind-plugin
```

For local development, add your checkout instead:

```bash
codex plugin marketplace add /path/to/hivemind-plugin
```

Restart Codex, open Plugins, and install or enable **Hivemind** from the Hivemind marketplace. Codex's CLI currently adds marketplaces; it does not expose a Claude-style `plugin install` subcommand.

The shared skill contents are the same ones Claude Code uses, but without relying on Claude-only packaging. If you prefer a skill-only setup, install `skills/hivemind` from this repo as a Codex skill.

Create the same credentials file used by the Claude and CLI flows:

```bash
mkdir -p ~/.config/hivemind
cat > ~/.config/hivemind/env <<'EOF'
HIVEMIND_API_KEY=hm_k_your_key_here
HIVEMIND_PROJECT_ID=
EOF
chmod 600 ~/.config/hivemind/env
```

Once installed in Codex, the skill can invoke the shared scripts from `skills/hivemind/scripts/`.

## Standalone CLI Install

Skip this section if you only plan to use Hivemind through Claude Code or Codex.

This installs the three CLIs onto your `PATH` so you can run them from any terminal.

```bash
git clone https://github.com/Myosin-xyz/hivemind-plugin.git
cd hivemind-plugin
./install.sh
```

The installer:

1. Copies `hivemind`, `hivemind-search`, `hivemind-project` to `~/.local/bin/`
2. Creates `~/.config/hivemind/env` from the template (chmod 600) — left alone if already present

If `~/.local/bin` isn't on your `PATH`, add it to your shell rc:

```bash
# bash / zsh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# fish
fish_add_path ~/.local/bin
```

### Configure credentials

Same as plugin flow — edit `~/.config/hivemind/env` and paste your key.

### Verify

```bash
hivemind chat --persona ghostwriter "Write one landing page headline for a test product"
```

### Uninstall

```bash
rm ~/.local/bin/hivemind ~/.local/bin/hivemind-search ~/.local/bin/hivemind-project
rm -rf ~/.config/hivemind
```

---

## Troubleshooting

### `Error: Credentials file not found at /home/you/.config/hivemind/env`

You skipped the env file creation. Run the commands under "Configure credentials" above.

### `Error: HIVEMIND_API_KEY not set`

The file exists but the key line is empty. Open it and paste the `hm_k_…` value.

### `401 invalid_key`

The key string is wrong, expired, or revoked. Double-check for trailing whitespace. If it looks right, the admin who issued it may have revoked it — request a new one.

### `429 rate_limited`

You exceeded 30 req/min. The error's `Retry-After` header tells you how long to wait. The CLI prints this automatically.

### `429 monthly_quota_exceeded`

You hit your monthly cap. Wait until the 1st of next UTC month or request a cap increase.

### `command not found: hivemind` (CLI install only)

`~/.local/bin` isn't on your `PATH`. Fix with the export shown above. This does not affect plugin users — Claude Code and Codex can invoke the shared scripts from inside the plugin checkout.

### Claude doesn't invoke the skill

1. Confirm the plugin is installed: `/plugin list` should show `hivemind`.
2. Bump or re-install if you cloned the repo and changed files locally — plugin caching keys on version.
3. Restart Claude Code.
4. In a fresh session, try a prompt that matches the skill description (e.g. "write me a landing page headline"). Generic prompts may not trigger it.

### Plugin install fails

- Make sure you're on a recent Claude Code release that supports `/plugin marketplace add <owner>/<repo>` shorthand.
- If the shorthand fails, try the full git URL: `/plugin marketplace add https://github.com/Myosin-xyz/hivemind-plugin.git`
- The repo must be public (or you must be authenticated with gh).

---

## Environment Variable Reference

All optional unless noted.

| Variable | Default | Description |
|---|---|---|
| `HIVEMIND_API_KEY` | — | **Required.** Your API key. |
| `HIVEMIND_PROJECT_ID` | — | Default project UUID for commands that accept one. |
| `HIVEMIND_API_URL` | `https://hivemind.myosin.xyz` | Override the API host. |
| `HIVEMIND_ENV_FILE` | `~/.config/hivemind/env` | Override the credentials file location. |
