#!/usr/bin/env python3
"""
Tear down and bring back the OpenClaw Docker Compose stack so config / bind-mount
changes are picked up reliably.

Usage (from this directory or any path):
  python3 redeploy_gateway.py
  python3 redeploy_gateway.py --quick          # skip "compose down" (faster)
  python3 redeploy_gateway.py --sync-config    # run ./sync-docker-config.sh first (jq + host openclaw.json)
  python3 redeploy_gateway.py --pull           # pull newer images before up

Requires: Docker Compose v2, docker on PATH, .env next to docker-compose.yml.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys


def main() -> None:
    compose_dir = os.path.dirname(os.path.abspath(__file__))
    compose_file = os.path.join(compose_dir, "docker-compose.yml")
    env_file = os.path.join(compose_dir, ".env")
    sync_script = os.path.join(compose_dir, "sync-docker-config.sh")

    parser = argparse.ArgumentParser(
        description="Redeploy OpenClaw (docker compose down + up --force-recreate).",
    )
    parser.add_argument(
        "--quick",
        action="store_true",
        help="Do not run 'docker compose down'; only recreate containers (faster).",
    )
    parser.add_argument(
        "--sync-config",
        action="store_true",
        help="Run sync-docker-config.sh first (regenerates openclaw.docker.json from ~/.openclaw/openclaw.json).",
    )
    parser.add_argument(
        "--pull",
        action="store_true",
        help="Run 'docker compose pull' before bringing containers up.",
    )
    parser.add_argument(
        "--build",
        action="store_true",
        help="Run 'docker compose build' before up (only if you build local images).",
    )
    parser.add_argument(
        "--gateway-only",
        action="store_true",
        help="Only recreate openclaw-gateway (default recreates all compose services).",
    )
    args = parser.parse_args()

    if not os.path.isfile(compose_file):
        print(f"Missing compose file: {compose_file}", file=sys.stderr)
        sys.exit(1)
    if not os.path.isfile(env_file):
        print(f"Missing env file: {env_file}", file=sys.stderr)
        sys.exit(1)

    def run(cmd: list[str]) -> None:
        print("+", " ".join(cmd), flush=True)
        subprocess.run(cmd, cwd=compose_dir, check=True)

    base = [
        "docker",
        "compose",
        "-f",
        compose_file,
        "--env-file",
        env_file,
    ]

    if args.sync_config:
        if not os.path.isfile(sync_script):
            print(f"--sync-config requested but missing: {sync_script}", file=sys.stderr)
            sys.exit(1)
        run(["bash", sync_script])

    if args.pull:
        run(base + ["pull"])

    if not args.quick:
        run(base + ["down"])

    if args.build:
        run(base + ["build"])

    up = base + ["up", "-d", "--force-recreate"]
    if args.gateway_only:
        up.append("openclaw-gateway")
    run(up)

    print("Done. Try: curl -sS http://127.0.0.1:18789/healthz", flush=True)
    try:
        subprocess.run(
            ["curl", "-sS", "-f", "--max-time", "10", "http://127.0.0.1:18789/healthz"],
            cwd=compose_dir,
            timeout=15,
            check=False,
        )
    except (subprocess.TimeoutExpired, FileNotFoundError):
        print("(curl not installed or gateway not ready — check: docker compose logs -f openclaw-gateway)")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}", file=sys.stderr)
        sys.exit(e.returncode)
