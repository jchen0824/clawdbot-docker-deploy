#!/usr/bin/env bash
set -euo pipefail

# Runs once to initialize config inside the persisted host mount.
# Uses Moltbot CLI (schema-aware) instead of hand-editing JSON.

# Ensure volumes are writable by the container's normal user (node).
# This init container runs as root (see docker-compose.yml).
echo "[init] fixing volume permissions"
# Ensure node user can read/write the state + workspace volumes.
chown -R node:node /home/node/.clawdbot /home/node/clawd || true
chmod 755 /home/node /home/node/clawd || true
chmod -R u+rwX,go+rX /home/node/.clawdbot 2>/dev/null || true

CLI=(node /app/dist/index.js)

echo "[init] onboarding (non-interactive)"
"${CLI[@]}" onboard --non-interactive --accept-risk \
  --mode local \
  --workspace /home/node/clawd \
  --gateway-port 18789 \
  --gateway-bind lan \
  --gateway-auth token \
  --gateway-token "$CLAWDBOT_GATEWAY_TOKEN" \
  --skip-daemon --skip-ui --skip-skills --skip-health

echo "[init] set session dm scope"
"${CLI[@]}" config set session.dmScope per-channel-peer

echo "[init] configure telegram allowlist"
"${CLI[@]}" config set channels.telegram.enabled true
"${CLI[@]}" config set channels.telegram.botToken "$TELEGRAM_BOT_TOKEN"
"${CLI[@]}" config set channels.telegram.dmPolicy allowlist

# Allowlist can be set as JSON array string, e.g.:
# TELEGRAM_ALLOW_FROM='["1459204134","123456789"]'
# Back-compat: if TELEGRAM_ALLOW_FROM not set, fall back to TELEGRAM_OWNER_ID.
ALLOW_FROM_JSON=${TELEGRAM_ALLOW_FROM:-"[\"$TELEGRAM_OWNER_ID\"]"}
"${CLI[@]}" config set --json channels.telegram.allowFrom "$ALLOW_FROM_JSON"

echo "[init] configure control ui (allow token auth over http on localhost/lan)"
"${CLI[@]}" config set gateway.controlUi.allowInsecureAuth true

echo "[init] configure web_search (Brave)"
# Prefer storing the key in config (tools.web.search.apiKey). This also works if you later remove BRAVE_API_KEY from env.
if [ -n "${BRAVE_API_KEY:-}" ]; then
  "${CLI[@]}" config set tools.web.search.enabled true
  "${CLI[@]}" config set tools.web.search.provider brave
  "${CLI[@]}" config set tools.web.search.apiKey "$BRAVE_API_KEY"
else
  echo "[init] BRAVE_API_KEY not set; skipping web_search setup"
fi

echo "[init] configure model providers"

# Two supported modes:
# 1) Direct Anthropic (recommended for simple onboarding): ANTHROPIC_API_KEY
# 2) LiteLLM proxy (optional): LITELLM_BASE_URL + LITELLM_API_KEY


OPENAI_MODELS='[
  {"id":"claude-opus-4-5","name":"Claude Opus 4.5","reasoning":false},
  {"id":"claude-sonnet-4-5","name":"Claude Sonnet 4.5","reasoning":false}
]'

ANTHROPIC_MODELS='[
  {"id":"claude-sonnet-4-5","name":"Claude Sonnet 4.5","reasoning":false},
  {"id":"claude-opus-4-5","name":"Claude Opus 4.5","reasoning":false}
]'

# IMPORTANT: provider configs are schema-validated as a unit. Set provider objects in one go.
"${CLI[@]}" config set models.mode merge

if [ -n "${LITELLM_BASE_URL:-}" ] && [ -n "${LITELLM_API_KEY:-}" ]; then
  echo "[init] using LiteLLM for model providers"

  OPENAI_PROVIDER=$(cat <<JSON
{
  "api": "openai-completions",
  "baseUrl": "${LITELLM_BASE_URL%/}/v1",
  "apiKey": "${LITELLM_API_KEY}",
  "models": ${OPENAI_MODELS}
}
JSON
)

  ANTHROPIC_PROVIDER=$(cat <<JSON
{
  "api": "anthropic-messages",
  "baseUrl": "${LITELLM_BASE_URL%/}/anthropic",
  "apiKey": "${LITELLM_API_KEY}",
  "models": ${ANTHROPIC_MODELS}
}
JSON
)

  "${CLI[@]}" config set --json models.providers.openai "$OPENAI_PROVIDER"
  "${CLI[@]}" config set --json models.providers.anthropic "$ANTHROPIC_PROVIDER"

elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "[init] using direct Anthropic API"

  ANTHROPIC_PROVIDER=$(cat <<JSON
{
  "api": "anthropic-messages",
  "baseUrl": "https://api.anthropic.com",
  "apiKey": "${ANTHROPIC_API_KEY}",
  "models": ${ANTHROPIC_MODELS}
}
JSON
)

  "${CLI[@]}" config set --json models.providers.anthropic "$ANTHROPIC_PROVIDER"

else
  echo "[init] ERROR: No model provider configured. Set ANTHROPIC_API_KEY (recommended) or LITELLM_BASE_URL+LITELLM_API_KEY." >&2
  exit 1
fi

echo "[init] set default model"
"${CLI[@]}" config set agents.defaults.model.primary anthropic/claude-sonnet-4-5

echo "[init] finalizing permissions"
# Make sure the gateway container (runs as user node) can read config files.
chown -R node:node /home/node/.clawdbot || true
chmod 700 /home/node/.clawdbot || true
chmod 600 /home/node/.clawdbot/*.json 2>/dev/null || true

echo "[init] done"
