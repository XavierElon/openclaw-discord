# OpenClaw (Docker)

Run the [OpenClaw](https://docs.openclaw.ai/install/docker) gateway in Docker while keeping a **native Mac config** in `~/.openclaw/openclaw.json` that does not use container paths.

## Restart the gateway (Docker)

From this directory (adjust the `cd` path if your repo lives elsewhere):

```bash
cd /path/to/overseer/openclaw
```

**Restart only the gateway** (usual after a small change):

```bash
docker compose --env-file .env restart openclaw-gateway
```

**Recreate the container** (pick up a new image, or refreshed bind-mounts / `openclaw.docker.json`):

```bash
docker compose --env-file .env up -d --force-recreate openclaw-gateway
```

**Restart all services in this compose file:**

```python
python3 redeploy_gateway.py
# After editing ~/.openclaw/openclaw.json — regen overlay + redeploy
python3 redeploy_gateway.py --sync-config
# Faster: no down
python3 redeploy_gateway.py --quick
python3 redeploy_gateway.py --help
```

```bash
docker compose --env-file .env down
docker compose --env-file .env up -d
```

**One-shot redeploy (tear down + recreate)** — same folder as `docker-compose.yml`:

```bash
python3 redeploy_gateway.py
```

After editing **`~/.openclaw/openclaw.json`**, regenerate the Docker overlay and redeploy:

```bash
python3 redeploy_gateway.py --sync-config
```

Flags: **`--quick`** (skip `down`, only `up --force-recreate`), **`--pull`**, **`--build`**, **`--gateway-only`**. See **`python3 redeploy_gateway.py --help`**.

**Restart Docker Desktop** (the whole engine): use the menu bar whale → **Restart**, or quit Docker and open it again. For config file changes, **`--force-recreate`** or `down` then `up` is more reliable than **`restart`** for remounts.

## Host vs Docker config

|                        | **Mac (`openclaw gateway`)**                                                    | **Docker (this compose file)**                                                                          |
| ---------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| Main config            | `~/.openclaw/openclaw.json`                                                     | Same directory on disk, but **`openclaw.json` inside the container is replaced** by a generated overlay |
| Workspace path in JSON | `/Users/…/.openclaw/workspace`                                                  | `/home/node/.openclaw/workspace` (bind-mount is still your real folder on the Mac)                      |
| Control UI             | `gateway.bind: loopback` in JSON; no extra origins needed for typical local use | Compose passes **`--bind lan`** → requires **`gateway.controlUi.allowedOrigins`** (localhost URLs)      |

**Shared state** (credentials, extensions, logs, etc.) lives under **`OPENCLAW_CONFIG_DIR`** (default **`~/.openclaw`**). Only **`openclaw.json` differs** in the container.

**Regenerate the Docker overlay** after you change plugins, channels, models, or gateway auth on the host:

```bash
cd /path/to/overseer/openclaw
./sync-docker-config.sh
```

(`jq` required: `brew install jq`. Override host path with `OPENCLAW_HOST_JSON=/path/to/openclaw.json`.)

The generated **`openclaw.docker.json`** is **gitignored** (it copies secrets from your host file). Commit only **`sync-docker-config.sh`** and this README.

### macOS paths in cron / agent state

If you ever ran **`openclaw` on the Mac**, OpenClaw may have saved **absolute paths** under **`/Users/...`** in files like **`~/.openclaw/agents/main/sessions/sessions.json`**. In Docker (Linux), those paths do not exist unless your **real home directory is bind-mounted at the same path** inside the container.

Compose does that with **`${OPENCLAW_HOST_HOME:-$HOME}`** → **`${OPENCLAW_HOST_HOME:-$HOME}`** (see `docker-compose.yml`). Run Compose from a shell where **`HOME`** is set (normal Terminal.app / iTerm), or set **`OPENCLAW_HOST_HOME=/Users/yourname`** in **`.env`**.

That avoids errors such as **`EACCES: permission denied, mkdir '/Users'`** when a scheduled job (for example **LeetCode daily digest**) runs. This **exposes your Mac home directory to the container**; only use it on machines you trust.

### Skills / `Path escapes sandbox root`

Persisted sessions often point at **`~/.nvm/.../openclaw/skills/*.md`**. In the container, **`HOME` is `/home/node`**, so `~/.nvm` means **`/home/node/.nvm`**. Compose bind-mounts your host **`$HOME/.nvm`** there (override with **`OPENCLAW_NVM_DIR`** in **`.env`**).

The Docker overlay from **`./sync-docker-config.sh`** also sets **`tools.fs.workspaceOnly`** to **`false`** so those skill paths are not blocked by the workspace-only sandbox (your **host** `openclaw.json` can stay stricter).

### `pairing required` / platform metadata (`linux` vs `darwin`)

A **gateway client** (CLI, Canvas, or device) connected with identity/metadata from your **Mac**, while the server runs in **Linux** (Docker). OpenClaw treats that as a **metadata upgrade** and may require **device pairing** again.

Complete pairing in the **OpenClaw** app or **Control UI** (approve the device / reconnect the client). Until pairing succeeds, WebSocket connections can close with **code 1008** and **`pairing required`**.

## Prerequisites

- Docker Desktop (or Docker Engine) with Compose v2
- A completed **`openclaw setup`** on your machine (so `~/.openclaw/openclaw.json` exists), _or_ a copy of that tree under `./data/config` (see below)

### Local open-source models (Ollama, no Google API quota)

To avoid **Gemini rate limits**, you can use **[Ollama](https://ollama.com)** on your Mac: models run locally, no cloud API key usage for chat.

**Subscription vs free:** Some **Ollama Cloud** models (for example names ending in **`:cloud`**, or Kimi routes) require an **Ollama.com** paid plan and return **403** if you are not subscribed. Models you **`ollama pull`** and run on your own machine are **free** aside from your electricity and hardware.

1. Install Ollama and keep it running (menu bar app or `ollama serve`).
2. Pull a small model (example used in config: **`llama3.2:3b`**):

   ```bash
   ollama pull llama3.2:3b
   ```

3. In **`~/.openclaw/openclaw.json`**, set **`agents.defaults.model.primary`** to **`ollama/llama3.2:3b`** (or **`ollama/<name>`** matching **`models.providers.ollama.models[].id`**). Point **`models.providers.ollama.baseUrl`** to **`http://127.0.0.1:11434/v1`** for native CLI on the Mac.

4. **Docker:** **`./sync-docker-config.sh`** rewrites Ollama’s **`baseUrl`** to **`http://host.docker.internal:11434/v1`** so the gateway container reaches Ollama on the host. Recreate the gateway after syncing.

5. Swap models anytime: **`ollama pull mistral:7b`** (heavier), **`gemma2:2b`** (lighter), then update **`primary`** and the **`models`** entry to match.

Google plugins can stay enabled for optional use; the **default** model drives most Discord traffic.

## Configure `.env`

1. Copy this folder’s `.env` as a starting point, or create one with at least:
   - **`DISCORD_BOT_TOKEN`** — Discord bot token (or set **`DISCORD_TOKEN`** and **`DISCORD_BOT_TOKEN=${DISCORD_TOKEN}`** as in the sample).
   - **`OPENCLAW_GATEWAY_TOKEN`** — gateway auth token (or set **`GATEWAY_TOKEN`** and **`OPENCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}`**).
   - **`OPENCLAW_CONFIG_DIR`** — absolute path to your OpenClaw config directory (usually **`$HOME/.openclaw`**).
   - **`OPENCLAW_WORKSPACE_DIR`** — absolute path to the workspace (usually **`$HOME/.openclaw/workspace`**).

2. Optional overrides (see `docker-compose.yml`):
   - **`OPENCLAW_IMAGE`** — default `ghcr.io/openclaw/openclaw:latest`
   - **`OPENCLAW_TZ`** — default `America/Los_Angeles`
   - **`OPENCLAW_GATEWAY_PORT`** / **`OPENCLAW_BRIDGE_PORT`** — host ports (defaults **18789** / **18790**)
   - **`OPENCLAW_GATEWAY_BIND`** — default `lan`
   - **`GEMINI_API_KEY`** and/or **`GOOGLE_API_KEY`** — at least one is enough for Google API-key auth (same key value; different env names for compatibility).

**Do not commit `.env`.** It is listed in `.gitignore`.

**Why Compose does not warn when these are missing:** `docker-compose.yml` uses optional substitution like **`${GEMINI_API_KEY:-}`**, which expands to an **empty string** when the variable is unset. That is valid Compose, so you get **no error or warning**. The gateway can still find a key because **`OPENCLAW_CONFIG_DIR`** is bind-mounted from the host (often **`~/.openclaw`**): **`openclaw onboard`** / CLI setup can store **`google:default`** in **`agents/main/agent/auth-profiles.json`**, and OpenClaw may use that even when **`.env`** omits **`GEMINI_API_KEY`**. Setting **`GOOGLE_API_KEY`** (or **`GEMINI_API_KEY`**) in **`.env`** anyway makes the key explicit inside the container and matches billing/quotas for the key you intend.

### LAN Control UI origins

If you use the gateway UI from another machine, add that URL to **`allowedOrigins`** in **`openclaw.docker.json`**. Easiest: run **`./sync-docker-config.sh`**, then edit **`openclaw.docker.json`** once to append the extra origin, or extend the `jq` command in the script.

### Alternative: config only inside this repo

If you prefer not to mount `~/.openclaw`:

```bash
mkdir -p ./data/config ./data/workspace
cp -a ~/.openclaw/. ./data/config/
# Then in .env, point OPENCLAW_CONFIG_DIR / OPENCLAW_WORKSPACE_DIR at ./data/... using absolute paths, or rely on compose defaults (./data/config and ./data/workspace).
```

## Run the gateway

From **this directory**:

```bash
docker compose --env-file .env up -d openclaw-gateway
```

Check status and logs:

```bash
docker compose --env-file .env ps -a
docker compose --env-file .env logs -f openclaw-gateway
```

Health check (from the host):

```bash
curl -sS http://127.0.0.1:18789/healthz
```

Default URLs: **http://127.0.0.1:18789** (gateway), bridge port **18790** (see compose for mapping).

### LeetCode daily digest (deterministic picks)

The digest is produced by **`workspace/scripts/leetcode-pick.mjs`** (same source as `../clawbot/leetcode-pick.mjs`). It calls LeetCode’s GraphQL API, skips IDs already logged under **`memory/leetcode-digest-*.md`**, and randomizes picks.

**Cron delivery (recommended):** OpenClaw’s scheduled job **reads** pre-generated text instead of calling **`exec`** (tool failures used to surface as raw JSON like `{"name":"exec",…}` in Discord).

1. **Host:** run **`scripts/run-leetcode-digest-for-cron.sh`** from this repo a minute or two **before** the cron time (e.g. cron at **7:00** → run the script at **6:58**). It **`docker compose exec`**’s into **`openclaw-gateway`** and writes **`memory/leetcode-digest-canned.txt`** under **`OPENCLAW_WORKSPACE_DIR`** (from **`.env`**).

   Example host **`crontab`** (adjust paths):

   ```cron
   58 6 * * * /bin/bash "/path/to/overseer/openclaw/scripts/run-leetcode-digest-for-cron.sh" >>"$HOME/Library/Logs/openclaw-leetcode-digest.log" 2>&1
   ```

2. **OpenClaw cron job** uses **`toolsAllow: ["read"]`** only and posts the contents of **`memory/leetcode-digest-canned.txt`** to Discord.

3. **`tools.alsoAllow`** in **`~/.openclaw/openclaw.json`** should include **`read`** for the messaging profile. **`exec`** is still useful for interactive chat when you want **`node scripts/leetcode-pick.mjs`**.

**Interactive Discord (Steve):** If the bot **invents** problem titles/IDs, **appends** extra lists after the digest, **renames** itself, or **pastes `{"name":"message",…}`** when you reply with a number, the usual cause is a **small local model** (for example **`ollama/llama3.2:3b`**) ignoring **`~/.openclaw/workspace/AGENTS.md`**. Use a **stronger model** for messaging (your **`openclaw.json`** Gemini / cloud route, or a larger Ollama tag), or keep **`exec`** + **`node scripts/leetcode-pick.mjs`** as the **only** source of problem lines. The script output always has matching **`#id`**, title, and URL; if Discord shows a wrong id next to a real slug, that line did **not** come from the script.

**Interactive:** use **`exec`** + **`node scripts/leetcode-pick.mjs`** as documented in **`AGENTS.md`**; **`tools.exec`** still needs **`allowlist`** + **`safeBinProfiles.node`** + **`safeBinTrustedDirs`** if you keep **`exec`** enabled.

After editing the host **`openclaw.json`**, run **`./sync-docker-config.sh`** and recreate the gateway when using Docker.

## Run CLI commands (one-off)

The **`openclaw-cli`** service uses the gateway’s network namespace. Example:

```bash
docker compose --env-file .env run --rm openclaw-cli cron list --token "$OPENCLAW_GATEWAY_TOKEN"
```

Use your real gateway token value in place of the variable if it is not exported in your shell.

## Start at login (macOS)

1. **Docker Desktop** → **Settings** → **General** → enable **“Start Docker Desktop when you log in”** (or the gateway will never get a daemon).
2. From this folder, **`start-on-login.sh`** waits for **`docker info`**, then runs **`docker compose --env-file .env up -d openclaw-gateway`**. Logs: **`~/Library/Logs/openclaw-compose.log`**.
3. Install a **LaunchAgent** (runs as you, after login):

   ```bash
   OPENCLAW_DIR="/Users/xavierelon/Library/Mobile Documents/com~apple~CloudDocs/coding/overseer/openclaw"
   sed -e "s|__OPENCLAW_DIR__|${OPENCLAW_DIR}|g" -e "s|__HOME__|${HOME}|g" \
     "${OPENCLAW_DIR}/com.openclaw.compose.plist.example" > "${HOME}/Library/LaunchAgents/com.openclaw.compose.plist"
   launchctl load "${HOME}/Library/LaunchAgents/com.openclaw.compose.plist"
   ```

   Adjust **`OPENCLAW_DIR`** if your repo lives elsewhere. Unload with **`launchctl unload ~/Library/LaunchAgents/com.openclaw.compose.plist`**.

4. Test once: **`"$OPENCLAW_DIR/start-on-login.sh"`** (with Docker already running).

## Stop / remove

```bash
docker compose --env-file .env stop openclaw-gateway
docker compose --env-file .env down
```

## Troubleshooting

| Symptom                                                         | What to check                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`Restarting (78)`** in `docker compose ps`                    | **`docker compose logs openclaw-gateway`**. Often **“Missing config”**: the mounted config dir has no `openclaw.json`. Set **`OPENCLAW_CONFIG_DIR`** to the directory that contains **`openclaw.json`**, or populate `./data/config`.                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Secrets / Discord errors                                        | Ensure **`DISCORD_BOT_TOKEN`** (and any keys referenced in `openclaw.json`) are set in `.env` and passed through compose.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **Discord bot never online**                                    | Check logs: if you see **Control UI requires … allowedOrigins**, run **`./sync-docker-config.sh`** and recreate the container.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| **`EACCES` / `mkdir '/Users'`**                                 | Run **`./sync-docker-config.sh`** so the Docker overlay uses **`/home/node/.openclaw/workspace`**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **`openclaw.docker.json` missing**                              | Run **`./sync-docker-config.sh`** before **`docker compose up`**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **Cron / Discord: `mkdir '/Users'` EACCES**                     | Persisted agent paths are macOS absolutes. Ensure the **home bind mount** is active: set **`OPENCLAW_HOST_HOME`** or run **`docker compose` with `HOME` set**, then **`docker compose up -d --force-recreate`**.                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **`Path escapes sandbox root` … `~/.nvm/.../skills`**           | Run **`./sync-docker-config.sh`**, ensure **`OPENCLAW_NVM_DIR`** points at your host **`~/.nvm`**, recreate the container.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| **`pairing required` / WS 1008**                                | Re-pair the client in OpenClaw after switching to Docker (platform metadata **linux** vs **darwin**).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Wrong user on Linux                                             | File permissions on the host config dir must allow the container user to read/write (see upstream Docker docs).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **`exec denied`** / Steve says **execution is blocked** for `node scripts/leetcode-pick.mjs` | Bundled **`discord`** skill sets **`allowed-tools: ["message"]`**, which hides **`exec`** on Discord even when **`openclaw.json`** allows it. Add **`$OPENCLAW_WORKSPACE_DIR/skills/discord/SKILL.md`** with **`allowed-tools: ["message", "exec", "read"]`** (workspace skills override bundled ones). **Stale cache:** Discord sessions store a frozen **`skillsSnapshot`** in **`~/.openclaw/agents/main/sessions/sessions.json`**; if Steve still says blocked after editing the SKILL, remove that session object’s **`skillsSnapshot`** (backup the file first) or talk in a **new channel / thread** so skills reload from disk.                                                                                                                                                                                                                                                                                                                                                             |
| **`LeetCode digest failed: {"name":"exec",…}`** in Discord      | The agent echoed a failed **`exec`** tool payload. Use the **read-file cron flow**: run **`scripts/run-leetcode-digest-for-cron.sh`** before 7:00 so **`memory/leetcode-digest-canned.txt`** exists; the OpenClaw cron job should use **`toolsAllow: ["read"]`** only (see README).                                                                                                                                                                                                                                                                                                                                                                                                   |
| **`{"name":"message","parameters":…}`** or **`//n`** in Discord | That text is the **`message` tool’s wire format**, not a normal chat message—plus broken “newlines.” Usually the **model** pasted JSON into visible output, or **duplicate-detection** merged odd strings; **`//n`** means `\n` was mangled. **Never** freehand LeetCode lists (your example mixes wrong **#id / titles**, e.g. Merge Sorted Array is not **#208**). Use **`node scripts/leetcode-pick.mjs`** so picks come from LeetCode’s API.                                                                                                                                                                                                                                      |
| Steve **hallucinates** problems or **wrong `#` next to a real URL** | Strengthen **`AGENTS.md`** (LeetCode + Discord sections under **`~/.openclaw/workspace/`**) and switch Discord / default agent off **`llama3.2:3b`** if it keeps improvising. For follow-ups (“different topic”, **`3`**), the agent must **`exec`** **`leetcode-pick.mjs`**—never type tool JSON as chat.                                                                                                                                                                                                                                                                    |

## Reference

- Install / Docker: [docs.openclaw.ai/install/docker](https://docs.openclaw.ai/install/docker)
