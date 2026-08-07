# open-webui — feature notes

ChatGPT-style web UI (`services.open-webui`) for chatting with the local
[ollama](../ollama/notes.md) models. Serves `http://127.0.0.1:8080`, loopback
only, firewall closed.

## Knowledge

- **Auth is disabled** (`WEBUI_AUTH = "False"`) — single local user behind
  loopback. If the UI is ever exposed beyond localhost (tailscale etc.), turn
  auth back on first; open-webui refuses `WEBUI_AUTH=False` once accounts exist
  in its DB.
- **State lives in `/var/lib/open-webui`** (`services.open-webui.stateDir`
  default) — chat history, settings, its SQLite DB.
- `ENABLE_OPENAI_API = "False"` — otherwise the UI probes api.openai.com on
  load and stalls without a key. Ollama is the only backend.
- First start is slow (DB migrations + frontend unpack); the feature test polls
  with `wait_until_succeeds` instead of a single curl.
- The UI proxies ollama at `/ollama/*` — handy for checking connectivity:
  `curl http://127.0.0.1:8080/ollama/api/version`.
