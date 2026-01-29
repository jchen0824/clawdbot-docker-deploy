# Moltbot (Clawdbot) Docker Deploy

This repo runs **Moltbot Gateway** (the Clawdbot runtime) in Docker using the upstream **official pattern**:

- `moltbot-init` (one-shot) initializes/updates config via the CLI (schema-aware)
- `clawdbot` (gateway) runs the gateway 24/7

State is **persisted on the host** via bind mounts (so `docker compose down` / `up` will not wipe config).

---

## Quick start (Mac / Docker Desktop)

### 1) Configure `.env`

```bash
cp .env.example .env
# edit .env
```

Required:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_OWNER_ID`
- `LITELLM_BASE_URL` (e.g. `http://host.docker.internal:4000`)
- `LITELLM_API_KEY`

Recommended:
- `GATEWAY_AUTH_TOKEN` (generate once: `openssl rand -hex 32`)

### 2) Start

```bash
docker compose up -d
```

### 3) Open Control UI

- UI: http://localhost:${GATEWAY_PORT}

If you see WS auth errors, open a **tokenized** URL once:

```
http://localhost:${GATEWAY_PORT}/?gatewayUrl=ws://127.0.0.1:${GATEWAY_PORT}&token=${GATEWAY_AUTH_TOKEN}
```

---

## Persistence (important)

On Mac, we persist to directories **inside this repo** (but gitignored):

- Config/state: `./data` → mounted to `/home/node/.clawdbot`
- Workspace: `./workspace` → mounted to `/home/node/clawd`

So yes: **`docker compose down` + `docker compose up -d` keeps your config**, as long as you don’t delete `./data`.

Warning: `git clean -xfd` will delete untracked dirs like `data/` and `workspace/`.

---

## Re-run init (apply env/config changes)

If you change env vars (token, LiteLLM URL/key, telegram allowlist, etc.):

```bash
docker compose run --rm moltbot-init
docker compose restart clawdbot
```

---

## Hetzner VPS (recommended layout)

Follow the upstream guide: https://docs.molt.bot/platforms/hetzner

Host directories (persisted):
- `/root/.clawdbot`
- `/root/clawd`

Container mount targets (same as this repo uses):
- `/home/node/.clawdbot`
- `/home/node/clawd`

Security best practice for VPS:
- bind the published port to loopback only (`127.0.0.1:18789:18789`)
- access via SSH tunnel

---

## Useful commands

```bash
# status
docker compose ps

# logs
docker compose logs -f

# shell
docker exec -it clawdbot-gateway sh

# stop
docker compose down
```
