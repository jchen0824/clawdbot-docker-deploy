#!/bin/bash
set -euo pipefail

# Clawdbot Docker Deployment Script
# Deploys Clawdbot with security best practices

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }
die() { error "$*"; exit 1; }

# === Pre-flight Checks ===

info "Clawdbot Docker Deployment"
echo

# Check Docker
command -v docker >/dev/null 2>&1 || die "Docker is not installed. Install from https://docs.docker.com/get-docker/"
docker info >/dev/null 2>&1 || die "Docker daemon is not running"
info "Docker: OK"

# Check Docker Compose
if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
else
    die "Docker Compose is not available"
fi
info "Docker Compose: OK"

# Check .env file
if [ ! -f .env ]; then
    warn ".env file not found"
    read -p "Create .env from template? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp .env.example .env
        info "Created .env from template"
        warn "IMPORTANT: Edit .env and add your API keys before continuing!"
        warn "Required: ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN, LITELLM_MASTER_KEY"
        read -p "Press Enter when ready to continue..."
    else
        die "Deployment cancelled. Create .env file first."
    fi
fi

# Validate required environment variables
source .env
REQUIRED_VARS=(
    "ANTHROPIC_API_KEY"
    "TELEGRAM_BOT_TOKEN"
    "LITELLM_MASTER_KEY"
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    error "Missing required environment variables in .env:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    die "Please configure .env before deploying"
fi
info "Environment: OK"

# Check file permissions
if [ "$(stat -f '%A' .env 2>/dev/null || stat -c '%a' .env 2>/dev/null)" != "600" ]; then
    warn ".env has insecure permissions, fixing..."
    chmod 600 .env
    info "Set .env permissions to 600"
fi

# === Deployment ===

info "Starting deployment..."
echo

# Pull latest images
info "Pulling Docker images..."
$COMPOSE_CMD pull

# Start services
info "Starting Clawdbot..."
$COMPOSE_CMD up -d

# Wait for health check
info "Waiting for Clawdbot to be ready..."
RETRIES=30
INTERVAL=2
for i in $(seq 1 $RETRIES); do
    if docker inspect clawdbot-gateway --format='{{.State.Health.Status}}' 2>/dev/null | grep -q "healthy"; then
        info "Clawdbot is healthy!"
        break
    fi
    if [ $i -eq $RETRIES ]; then
        warn "Health check timed out. Check logs with: $COMPOSE_CMD logs"
    fi
    sleep $INTERVAL
done

# === Post-Deployment ===

echo
info "Deployment complete!"
echo
info "Next steps:"
echo "  1. Configure Clawdbot:"
echo "     docker exec -it clawdbot-gateway clawdbot configure"
echo
echo "  2. Check logs:"
echo "     $COMPOSE_CMD logs -f"
echo
echo "  3. Check status:"
echo "     $COMPOSE_CMD ps"
echo
echo "  4. Access gateway:"
echo "     http://localhost:${GATEWAY_PORT:-18789}"
echo
info "Security reminders:"
echo "  - Gateway is bound to localhost only (safe)"
echo "  - Use a reverse proxy (nginx/caddy) for external access"
echo "  - Keep .env file secure (permissions: 600)"
echo "  - Rotate API keys regularly"
echo
