#!/usr/bin/env bash
# Hivemind standalone CLI installer.
#
# Installs the three CLIs onto $PATH (~/.local/bin) and scaffolds
# ~/.config/hivemind/env so you can call the Hivemind API from any terminal.
#
# You do NOT need to run this if you installed the plugin via:
#   /plugin marketplace add Myosin-xyz/hivemind-skill
#   /plugin install hivemind@hivemind
# The plugin loader invokes the scripts from inside the plugin directory.
#
# Idempotent; safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/hivemind"
ENV_FILE="${CONFIG_DIR}/env"
ENV_TEMPLATE="${SCRIPT_DIR}/config/env.example"
SKILL_SCRIPTS="${SCRIPT_DIR}/skills/hivemind/scripts"

missing=()
for cmd in bash curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    missing+=("$cmd")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing required tools: ${missing[*]}" >&2
  echo "Install them and re-run this script." >&2
  exit 1
fi

echo "Installing Hivemind CLI (standalone)..."

mkdir -p "$BIN_DIR"
for script in hivemind hivemind-search hivemind-project; do
  src="${SKILL_SCRIPTS}/${script}"
  if [[ ! -f "$src" ]]; then
    echo "Error: missing $src. Is the repo checkout complete?" >&2
    exit 1
  fi
  install -m 0755 "$src" "${BIN_DIR}/${script}"
  echo "  installed ${BIN_DIR}/${script}"
done

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"
if [[ -f "$ENV_FILE" ]]; then
  echo "  credentials file already exists at ${ENV_FILE} (left untouched)"
else
  cp "$ENV_TEMPLATE" "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  echo "  created ${ENV_FILE} (mode 600)"
fi

case ":$PATH:" in
  *":${BIN_DIR}:"*)
    path_warning=""
    ;;
  *)
    path_warning="yes"
    ;;
esac

cat <<EOF

Done.

Next steps:
  1. Edit ${ENV_FILE} and paste your API key:
       HIVEMIND_API_KEY=hm_k_...

     Don't have a key? Request one at:
       https://myosin.typeform.com/api-request

  2. Verify:
       hivemind chat --persona ghostwriter "Write one test headline"

EOF

if [[ -n "$path_warning" ]]; then
  cat <<EOF
Warning: ${BIN_DIR} is not on your PATH. Add it to your shell rc:
  bash/zsh:  echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.bashrc
  fish:      fish_add_path ~/.local/bin

EOF
fi

cat <<EOF
To use Hivemind inside Claude Code, install it as a plugin instead:
  /plugin marketplace add Myosin-xyz/hivemind-skill
  /plugin install hivemind@hivemind

Claude will auto-invoke the skill via the plugin — the standalone CLI you
just installed is only needed for non-Claude use.
EOF
