#!/usr/bin/env bash
# Generate ~/.openclaw/workspace/memory/leetcode-digest-canned.txt by running
# leetcode-pick.mjs inside the gateway container (same network/fs as OpenClaw).
# Schedule this ~2 minutes BEFORE the OpenClaw cron (e.g. 6:58 if cron is 7:00).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${COMPOSE_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing ${ENV_FILE}" >&2
  exit 1
fi

# Resolve OPENCLAW_WORKSPACE_DIR from .env (fallback: ~/.openclaw/workspace)
_line="$(grep -E '^[[:space:]]*OPENCLAW_WORKSPACE_DIR=' "${ENV_FILE}" 2>/dev/null | tail -1 || true)"
if [[ -n "${_line}" ]]; then
  WS="${_line#*=}"
  WS="${WS//$'\r'/}"
  WS="${WS//\"/}"
  WS="${WS//\'/}"
else
  WS="${HOME}/.openclaw/workspace"
fi

OUT="${WS}/memory/leetcode-digest-canned.txt"
mkdir -p "$(dirname "${OUT}")"

docker compose -f "${COMPOSE_DIR}/docker-compose.yml" --env-file "${ENV_FILE}" exec -T openclaw-gateway \
  sh -lc 'cd /home/node/.openclaw/workspace && node scripts/leetcode-pick.mjs' \
  > "${OUT}"

echo "Wrote $(wc -c < "${OUT}" | tr -d ' ') bytes to ${OUT}"
