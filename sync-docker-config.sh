#!/usr/bin/env bash
# Regenerate openclaw.docker.json from your host config (~/.openclaw/openclaw.json).
# Docker Compose bind-mounts that file over the shared config dir inside the container.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST_JSON="${OPENCLAW_HOST_JSON:-$HOME/.openclaw/openclaw.json}"
OUT_JSON="${ROOT}/openclaw.docker.json"

if [[ ! -f "$HOST_JSON" ]]; then
  echo "Missing host config: $HOST_JSON" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "jq is required (brew install jq)" >&2
  exit 1
fi

jq '
  .agents.defaults.workspace = "/home/node/.openclaw/workspace" |
  .gateway.controlUi.allowedOrigins = [
    "http://127.0.0.1:18789",
    "http://localhost:18789"
  ] |
  # Native CLI stores skill paths under ~/.nvm/...; in Docker HOME=/home/node. Allow fs reads outside
  # workspace only in the container overlay (host openclaw.json can keep workspaceOnly: true).
  .tools.fs.workspaceOnly = false |
  # Ollama runs on the Mac; 127.0.0.1 inside the container is not the host. Point at Docker Desktop.
  .models.providers.ollama.baseUrl = "http://host.docker.internal:11434/v1"
' "$HOST_JSON" >"${OUT_JSON}.tmp"
mv "${OUT_JSON}.tmp" "$OUT_JSON"
chmod 600 "$OUT_JSON" 2>/dev/null || true
echo "Wrote $OUT_JSON (from $HOST_JSON)"
