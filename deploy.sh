#!/usr/bin/env bash
set -euo pipefail

# Minimal deploy wrapper (kept intentionally simple).
# - validates .env exists
# - starts compose

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Missing .env. Run: cp .env.example .env && edit it" >&2
  exit 1
fi

# shellcheck disable=SC1091
source .env

: "${TELEGRAM_BOT_TOKEN:?Missing TELEGRAM_BOT_TOKEN in .env}"
# Require either TELEGRAM_ALLOW_FROM (preferred) or TELEGRAM_OWNER_ID (back-compat)
if [ -z "${TELEGRAM_ALLOW_FROM:-}" ] && [ -z "${TELEGRAM_OWNER_ID:-}" ]; then
  echo "Missing TELEGRAM_ALLOW_FROM (preferred) or TELEGRAM_OWNER_ID (back-compat) in .env" >&2
  exit 1
fi
# Require either direct Anthropic key OR LiteLLM config
if [ -z "${ANTHROPIC_API_KEY:-}" ] && { [ -z "${LITELLM_BASE_URL:-}" ] || [ -z "${LITELLM_API_KEY:-}" ]; }; then
  echo "Missing model provider config. Set ANTHROPIC_API_KEY (recommended) or LITELLM_BASE_URL+LITELLM_API_KEY in .env" >&2
  exit 1
fi
: "${GATEWAY_AUTH_TOKEN:?Missing GATEWAY_AUTH_TOKEN in .env}"

mkdir -p "${CLAWDBOT_CONFIG_DIR:-./data}" "${CLAWDBOT_WORKSPACE_DIR:-./workspace}"

chmod 600 .env 2>/dev/null || true

docker compose up -d

echo
echo "Up ✅"
echo "UI: http://localhost:${GATEWAY_PORT:-18790}"
echo "Tokenized URL (open once):"
echo "http://localhost:${GATEWAY_PORT:-18790}/?gatewayUrl=ws://127.0.0.1:${GATEWAY_PORT:-18790}&token=${GATEWAY_AUTH_TOKEN}"
