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

echo "[init] configure LiteLLM providers"

OPENAI_MODELS='[
  {"id":"claude-opus-4-5","name":"Claude Opus 4.5 (via LiteLLM)"},
  {"id":"claude-sonnet-4-5","name":"Claude Sonnet 4.5 (via LiteLLM)"},
  {"id":"chatgpt/gpt-5.2","name":"ChatGPT GPT-5.2 (via LiteLLM)"}
]'

ANTHROPIC_MODELS='[
  {"id":"claude-sonnet-4-5","name":"Claude Sonnet 4.5 (via LiteLLM passthrough)"},
  {"id":"claude-opus-4-5","name":"Claude Opus 4.5 (via LiteLLM passthrough)"}
]'

# IMPORTANT: provider configs are schema-validated as a unit. Set the provider objects in one go.
"${CLI[@]}" config set models.mode merge

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

echo "[init] set default model"
"${CLI[@]}" config set agents.defaults.model.primary anthropic/claude-sonnet-4-5

echo "[init] finalizing permissions"
# Make sure the gateway container (runs as user node) can read config files.
chown -R node:node /home/node/.clawdbot || true
chmod 700 /home/node/.clawdbot || true
chmod 600 /home/node/.clawdbot/*.json 2>/dev/null || true

echo "[init] done"
