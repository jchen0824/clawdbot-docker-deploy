#!/usr/bin/env bash
set -euo pipefail

# Upsert an A record in GoDaddy via API.
# Required env:
#   GODADDY_API_KEY
#   GODADDY_API_SECRET
# Args:
#   $1 root_domain (e.g. runonclawd.com)
#   $2 name (e.g. cust-123)  # use "@" for apex
#   $3 ip (e.g. 1.2.3.4)
#   $4 ttl (optional, default 600)

ROOT_DOMAIN="${1:?root_domain required}"
NAME="${2:?record name required}"
IP="${3:?ip required}"
TTL="${4:-600}"

AUTH="sso-key ${GODADDY_API_KEY:?missing}: ${GODADDY_API_SECRET:?missing}"
# Note: GoDaddy expects header: Authorization: sso-key <key>:<secret>
AUTH="sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}"

API="https://api.godaddy.com/v1"

payload=$(cat <<JSON
[
  {
    "data": "${IP}",
    "ttl": ${TTL}
  }
]
JSON
)

curl -fsS -X PUT "${API}/domains/${ROOT_DOMAIN}/records/A/${NAME}" \
  -H "Authorization: ${AUTH}" \
  -H "Content-Type: application/json" \
  -d "${payload}" >/dev/null

echo "GoDaddy DNS updated: ${NAME}.${ROOT_DOMAIN} -> ${IP} (ttl=${TTL})"
