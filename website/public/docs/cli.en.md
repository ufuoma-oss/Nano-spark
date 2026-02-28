# CLI

`nanospark` is the command-line tool for NanoSpark. This page is organized from
"get-up-and-running" to "advanced management" — read from top to bottom if
you're new, or jump to the section you need.

> Not sure what "channels", "heartbeat", or "cron" mean? See
> [Introduction](./intro) first.

---

## Getting started

These are the commands you'll use on day one.

### nanospark init

First-time setup. Walks you through configuration interactively.

```bash
nanospark init              # Interactive setup (recommended for first time)
nanospark init --defaults   # Non-interactive, use all defaults (good for scripts)
nanospark init --force      # Overwrite existing config files
```

**What the interactive flow covers (in order):**

1. **Heartbeat** — interval (e.g. `30m`), target (`main` / `last`), optional
   active hours.
2. **Show tool details** — whether tool call details appear in channel messages.
3. **Language** — `zh` or `en` for agent persona files (SOUL.md, etc.).
4. **Channels** — optionally configure iMessage / Discord / DingTalk / Feishu /
   QQ / Console.
5. **LLM provider** — select provider, enter API key, choose model (**required**).
6. **Skills** — enable all / none / custom selection.
7. **Environment variables** — optionally add key-value pairs for tools.
8. **HEARTBEAT.md** — edit the heartbeat checklist in your default editor.

### nanospark app

Start the NanoSpark server. Everything else — channels, cron jobs, the Console
UI — depends on this.

```bash
nanospark app                             # Start on 127.0.0.1:8088
nanospark app --host 0.0.0.0 --port 9090 # Custom address
nanospark app --reload                    # Auto-reload on code change (dev)
nanospark app --workers 4                 # Multi-worker mode
nanospark app --log-level debug           # Verbose logging
```

| Option        | Default     | Description                                                   |
| ------------- | ----------- | ------------------------------------------------------------- |
| `--host`      | `127.0.0.1` | Bind host                                                     |
| `--port`      | `8088`      | Bind port                                                     |
| `--reload`    | off         | Auto-reload on file changes (dev only)                        |
| `--workers`   | `1`         | Number of worker processes                                    |
| `--log-level` | `info`      | `critical` / `error` / `warning` / `info` / `debug` / `trace` |

### Console

Once `nanospark app` is running, open `http://127.0.0.1:8088/` in your browser to
access the **Console** — a web UI for chat, channels, cron, skills, models,
and more. See [Console](./console) for a full walkthrough.

If the frontend was not built, the root URL returns `{"message": "Hello World"}`
but the API still works.

**To build the frontend:** in the project's `console/` directory run
`npm ci && npm run build` (output in `console/dist/`). Docker images and pip
packages already include the Console.

---

## Models & environment variables

Before using NanoSpark you need at least one LLM provider configured. Environment
variables power many built-in tools (e.g. web search).

### nanospark models

Manage LLM providers and the active model.

| Command                                | What it does                                         |
| -------------------------------------- | ---------------------------------------------------- |
| `nanospark models list`                    | Show all providers, API key status, and active model |
| `nanospark models config`                  | Full interactive setup: API keys → active model      |
| `nanospark models config-key [provider]`   | Configure a single provider's API key                |
| `nanospark models set-llm`                 | Switch the active model (API keys unchanged)         |
| `nanospark models download <repo_id>`      | Download a local model (llama.cpp / MLX)             |
| `nanospark models local`                   | List downloaded local models                         |
| `nanospark models remove-local <model_id>` | Delete a downloaded local model                      |
| `nanospark models ollama-pull <model>`     | Download an Ollama model                             |
| `nanospark models ollama-list`             | List Ollama models                                   |
| `nanospark models ollama-remove <model>`   | Delete an Ollama model                               |

```bash
nanospark models list                    # See what's configured
nanospark models config                  # Full interactive setup
nanospark models config-key modelscope   # Just set ModelScope's API key
nanospark models config-key dashscope    # Just set DashScope's API key
nanospark models config-key custom       # Set custom provider (Base URL + key)
nanospark models set-llm                 # Change active model only
```

#### Local models

NanoSpark can also run models locally via llama.cpp or MLX — no API key needed.
Install the backend first: `pip install 'nanospark[llamacpp]'` or
`pip install 'nanospark[mlx]'`.

```bash
# Download a model (auto-selects Q4_K_M GGUF)
nanospark models download Qwen/Qwen3-4B-GGUF

# Download an MLX model
nanospark models download Qwen/Qwen3-4B --backend mlx

# Download from ModelScope
nanospark models download Qwen/Qwen2-0.5B-Instruct-GGUF --source modelscope

# List downloaded models
nanospark models local
nanospark models local --backend mlx

# Delete a downloaded model
nanospark models remove-local <model_id>
nanospark models remove-local <model_id> --yes   # skip confirmation
```

| Option      | Short | Default       | Description                                                           |
| ----------- | ----- | ------------- | --------------------------------------------------------------------- |
| `--backend` | `-b`  | `llamacpp`    | Target backend (`llamacpp` or `mlx`)                                  |
| `--source`  | `-s`  | `huggingface` | Download source (`huggingface` or `modelscope`)                       |
| `--file`    | `-f`  | _(auto)_      | Specific filename. If omitted, auto-selects (prefers Q4_K_M for GGUF) |

#### Ollama models

NanoSpark integrates with Ollama to run models locally. Models are dynamically loaded from your Ollama daemon — install Ollama first from [ollama.com](https://ollama.com).

Install the Ollama SDK: `pip install ollama`

```bash
# Download an Ollama model
nanospark models ollama-pull mistral:7b
nanospark models ollama-pull qwen3:8b

# List Ollama models
nanospark models ollama-list

# Remove an Ollama model
nanospark models ollama-remove mistral:7b
nanospark models ollama-remove qwen3:8b --yes   # skip confirmation

# Use in config flow (auto-detects Ollama models)
nanospark models config           # Select Ollama → Choose from model list
nanospark models set-llm          # Switch to a different Ollama model
```

**Key differences from local models:**

- Models come from Ollama daemon (not downloaded by NanoSpark)
- Use `ollama-pull` / `ollama-remove` instead of `download` / `remove-local`
- Model list updates dynamically when you add/remove via Ollama CLI or NanoSpark

> **Note:** You are responsible for ensuring the API key is valid. NanoSpark does
> not verify key correctness. See [Config — LLM Providers](./config#llm-providers).

### nanospark env

Manage environment variables used by tools and skills at runtime.

| Command                   | What it does                  |
| ------------------------- | ----------------------------- |
| `nanospark env list`          | List all configured variables |
| `nanospark env set KEY VALUE` | Set or update a variable      |
| `nanospark env delete KEY`    | Delete a variable             |

```bash
nanospark env list
nanospark env set TAVILY_API_KEY "tvly-xxxxxxxx"
nanospark env set GITHUB_TOKEN "ghp_xxxxxxxx"
nanospark env delete TAVILY_API_KEY
```

> **Note:** NanoSpark only stores and loads these values; you are responsible for
> ensuring they are correct. See
> [Config — Environment Variables](./config#environment-variables).

---

## Channels

Connect NanoSpark to messaging platforms.

### nanospark channels

Manage channel configuration (iMessage, Discord, DingTalk, Feishu, QQ,
Console, etc.). **Note:** Use `config` for interactive setup (no `configure`
subcommand); use `remove` to uninstall custom channels (no `uninstall`).

| Command                        | What it does                                                                                                      |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------- |
| `nanospark channels list`          | Show all channels and their status (secrets masked)                                                               |
| `nanospark channels install <key>` | Install a channel into `custom_channels/`: create stub or use `--path`/`--url`                                    |
| `nanospark channels add <key>`     | Install and add to config; built-in channels only get config entry; supports `--path`/`--url`                     |
| `nanospark channels remove <key>`  | Remove a custom channel from `custom_channels/` (built-ins cannot be removed); `--keep-config` keeps config entry |
| `nanospark channels config`        | Interactively enable/disable channels and fill in credentials                                                     |

```bash
nanospark channels list                    # See current status
nanospark channels install my_channel      # Create custom channel stub
nanospark channels install my_channel --path ./my_channel.py
nanospark channels add dingtalk            # Add DingTalk to config
nanospark channels remove my_channel       # Remove custom channel (and from config by default)
nanospark channels remove my_channel --keep-config   # Remove module only, keep config entry
nanospark channels config                 # Interactive configuration
```

The interactive `config` flow lets you pick a channel, enable/disable it, and enter credentials. It loops until you choose "Save and exit".

| Channel      | Fields to fill in                             |
| ------------ | --------------------------------------------- |
| **iMessage** | Bot prefix, database path, poll interval      |
| **Discord**  | Bot prefix, Bot Token, HTTP proxy, proxy auth |
| **DingTalk** | Bot prefix, Client ID, Client Secret          |
| **Feishu**   | Bot prefix, App ID, App Secret                |
| **QQ**       | Bot prefix, App ID, Client Secret             |
| **Console**  | Bot prefix                                    |

> For platform-specific credential setup, see [Channels](./channels).

---

## Cron (scheduled tasks)

Create jobs that run on a timed schedule — "every day at 9am", "every 2 hours
ask NanoSpark and send the reply". **Requires `nanospark app` to be running.**

### nanospark cron

| Command                      | What it does                                  |
| ---------------------------- | --------------------------------------------- |
| `nanospark cron list`            | List all jobs                                 |
| `nanospark cron get <job_id>`    | Show a job's spec                             |
| `nanospark cron state <job_id>`  | Show runtime state (next run, last run, etc.) |
| `nanospark cron create ...`      | Create a job                                  |
| `nanospark cron delete <job_id>` | Delete a job                                  |
| `nanospark cron pause <job_id>`  | Pause a job                                   |
| `nanospark cron resume <job_id>` | Resume a paused job                           |
| `nanospark cron run <job_id>`    | Run once immediately                          |

### Creating jobs

**Option 1 — CLI arguments (simple jobs)**

Two task types:

- **text** — send a fixed message to a channel on schedule.
- **agent** — ask NanoSpark a question on schedule and deliver the reply.

```bash
# Text: send "Good morning!" to DingTalk every day at 9:00
nanospark cron create \
  --type text \
  --name "Daily 9am" \
  --cron "0 9 * * *" \
  --channel dingtalk \
  --target-user "your_user_id" \
  --target-session "session_id" \
  --text "Good morning!"

# Agent: every 2 hours, ask NanoSpark and forward the reply
nanospark cron create \
  --type agent \
  --name "Check todos" \
  --cron "0 */2 * * *" \
  --channel dingtalk \
  --target-user "your_user_id" \
  --target-session "session_id" \
  --text "What are my todo items?"
```

Required: `--type`, `--name`, `--cron`, `--channel`, `--target-user`,
`--target-session`, `--text`.

**Option 2 — JSON file (complex or batch)**

```bash
nanospark cron create -f job_spec.json
```

JSON structure matches the output of `nanospark cron get <job_id>`.

### Additional options

| Option                       | Default | Description                                           |
| ---------------------------- | ------- | ----------------------------------------------------- |
| `--timezone`                 | `UTC`   | Timezone for the cron schedule                        |
| `--enabled` / `--no-enabled` | enabled | Create enabled or disabled                            |
| `--mode`                     | `final` | `stream` (incremental) or `final` (complete response) |
| `--base-url`                 | auto    | Override the API base URL                             |

### Cron expression cheat sheet

Five fields: **minute hour day month weekday** (no seconds).

| Expression     | Meaning                   |
| -------------- | ------------------------- |
| `0 9 * * *`    | Every day at 9:00         |
| `0 */2 * * *`  | Every 2 hours on the hour |
| `30 8 * * 1-5` | Weekdays at 8:30          |
| `0 0 * * 0`    | Sunday at midnight        |
| `*/15 * * * *` | Every 15 minutes          |

---

## Chats (sessions)

Manage chat sessions via the API. **Requires `nanospark app` to be running.**

### nanospark chats

| Command                                | What it does                                                  |
| -------------------------------------- | ------------------------------------------------------------- |
| `nanospark chats list`                     | List all sessions (supports `--user-id`, `--channel` filters) |
| `nanospark chats get <id>`                 | View a session's details and message history                  |
| `nanospark chats create ...`               | Create a new session                                          |
| `nanospark chats update <id> --name "..."` | Rename a session                                              |
| `nanospark chats delete <id>`              | Delete a session                                              |

```bash
nanospark chats list
nanospark chats list --user-id alice --channel dingtalk
nanospark chats get 823845fe-dd13-43c2-ab8b-d05870602fd8
nanospark chats create --session-id "discord:alice" --user-id alice --name "My Chat"
nanospark chats create -f chat.json
nanospark chats update <chat_id> --name "Renamed"
nanospark chats delete <chat_id>
```

---

## Skills

Extend NanoSpark's capabilities with skills (PDF reading, web search, etc.).

### nanospark skills

| Command               | What it does                                      |
| --------------------- | ------------------------------------------------- |
| `nanospark skills list`   | Show all skills and their enabled/disabled status |
| `nanospark skills config` | Interactively enable/disable skills (checkbox UI) |

```bash
nanospark skills list     # See what's available
nanospark skills config   # Toggle skills on/off interactively
```

In the interactive UI: ↑/↓ to navigate, Space to toggle, Enter to confirm.
A preview of changes is shown before applying.

> For built-in skill details and custom skill authoring, see [Skills](./skills).

---

## Maintenance

### nanospark clean

Remove everything under the working directory (default `~/.nanospark`).

```bash
nanospark clean             # Interactive confirmation
nanospark clean --yes       # No confirmation
nanospark clean --dry-run   # Only list what would be removed
```

---

## Global options

Every `nanospark` subcommand inherits:

| Option          | Default     | Description                                    |
| --------------- | ----------- | ---------------------------------------------- |
| `--host`        | `127.0.0.1` | API host (auto-detected from last `nanospark app`) |
| `--port`        | `8088`      | API port (auto-detected from last `nanospark app`) |
| `-h` / `--help` |             | Show help message                              |

If the server runs on a non-default address, pass these globally:

```bash
nanospark --host 0.0.0.0 --port 9090 cron list
```

## Working directory

All config and data live in `~/.nanospark` by default: `config.json`,
`HEARTBEAT.md`, `jobs.json`, `chats.json`, skills, memory, and agent persona
files.

| Variable            | Description                         |
| ------------------- | ----------------------------------- |
| `NANOSPARK_WORKING_DIR` | Override the working directory path |
| `NANOSPARK_CONFIG_FILE` | Override the config file path       |

See [Config & Working Directory](./config) for full details.

---

## Command overview

| Command          | Subcommands                                                                                                                            | Requires server? |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------- | :--------------: |
| `nanospark init`     | —                                                                                                                                      |        No        |
| `nanospark app`      | —                                                                                                                                      |  — (starts it)   |
| `nanospark models`   | `list` · `config` · `config-key` · `set-llm` · `download` · `local` · `remove-local` · `ollama-pull` · `ollama-list` · `ollama-remove` |        No        |
| `nanospark env`      | `list` · `set` · `delete`                                                                                                              |        No        |
| `nanospark channels` | `list` · `install` · `add` · `remove` · `config`                                                                                       |        No        |
| `nanospark cron`     | `list` · `get` · `state` · `create` · `delete` · `pause` · `resume` · `run`                                                            |     **Yes**      |
| `nanospark chats`    | `list` · `get` · `create` · `update` · `delete`                                                                                        |     **Yes**      |
| `nanospark skills`   | `list` · `config`                                                                                                                      |        No        |
| `nanospark clean`    | —                                                                                                                                      |        No        |

---

## Related pages

- [Introduction](./intro) — What NanoSpark can do
- [Console](./console) — Web-based management UI
- [Channels](./channels) — DingTalk, Feishu, iMessage, Discord, QQ setup
- [Heartbeat](./heartbeat) — Scheduled check-in / digest
- [Skills](./skills) — Built-in and custom skills
- [Config & Working Directory](./config) — Working directory and config.json
