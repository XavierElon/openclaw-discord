#!/usr/bin/env bash
# Run after login once Docker is up: brings up openclaw-gateway via Compose.
# Use with LaunchAgents (see README). Paths with spaces are supported.
set -euo pipefail

COMPOSE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${HOME}/Library/Logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/openclaw-compose.log"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH:-}"

log() {
  echo "$(date '+%Y-%m-%dT%H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log "openclaw start-on-login: COMPOSE_DIR=$COMPOSE_DIR"

if ! command -v docker &>/dev/null; then
  log "docker not found in PATH; install Docker Desktop or add it to PATH"
  exit 1
fi

# Wait for Docker daemon (Desktop can take a bit right after login).
for _ in $(seq 1 90); do
  if docker info &>/dev/null; then
    break
  fi
  sleep 2
done

if ! docker info &>/dev/null; then
  log "Docker daemon not reachable after wait; is Docker Desktop starting at login?"
  exit 1
fi

cd "$COMPOSE_DIR"
docker compose --env-file .env -f docker-compose.yml up -d openclaw-gateway >>"$LOG_FILE" 2>&1
log "docker compose up -d openclaw-gateway exit=$?"
