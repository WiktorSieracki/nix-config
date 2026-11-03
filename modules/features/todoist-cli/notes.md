# todoist-cli — feature notes

## 2026-11-03 — split out of `todoist`

`td` (Doist's official `todoist-cli`) and the agents' `todo` skill used to ship
inside `todoist`, which `requires` `desktop`, so a headless host could not have
them. They now live here as a `cli` feature; `todoist` requires it for the bar
plugin. The skill's history, the `td add` vs `td task add` gotcha and the
evals (`todo-evals/`) are in `../apps/todoist/notes.md` (2026-10-16/17).

**Logging in on a headless host (the VPS).** `td auth login` opens a browser
and waits for the OAuth redirect on `localhost:<port>/callback` — on the VPS,
not on the machine the browser runs on. What works:

1. `td auth login --no-browser-open --credential-store plaintext`. There is no
   keyring on the VPS, so the default `system` store has nowhere to go. Run it
   under a pty (`script -qfc …`) if its output is captured, or the URL never
   shows up.
2. Open the printed URL anywhere and approve. The browser lands on a dead
   `http://localhost:<port>/callback?code=…&state=…`.
3. `curl` that exact URL on the VPS; the waiting `td` finishes the exchange.

The redirect port is not always the one passed in `--callback-port` (asked for
8765, got 8766), so copy the URL as-is. The token ends up in
`~/.config/todoist-cli/config.json`. `td auth token <token>` (API token from
Settings → Integrations → Developer) is the no-browser alternative.
