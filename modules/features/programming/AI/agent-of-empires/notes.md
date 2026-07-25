# agent-of-empires — feature notes

2026-06-26: Added featureMeta + a feature test.

The feature uses the `aoe-with-web` package from the flake `github:agent-of-empires/agent-of-empires`.
Available packages: `default` (CLI/TUI only), `aoe-with-web` (with a web dashboard), `aoe-web-frontend`.
Main binary: `aoe` (meta.mainProgram = "aoe").

The feature also bundles `pkgs.tmux` because aoe manages sessions through tmux.

2026-07-26: Added `requires = ["claude-agent-acp"]`.

aoe's Structured view is an ACP frontend: it does not talk to any model itself,
it spawns a per-agent adapter binary looked up **by name on `$PATH`** and speaks
JSON-RPC to it. aoe ships no adapters. Without one, picking Structured fails
with "ACP adapter `claude-agent-acp` is not installed or not on $PATH".

Its suggested remedies (`npm install -g …`, `aoe acp doctor --fix`) cannot work
on NixOS — npm's global prefix is the read-only nodejs store path, so both die
with EROFS. Declare the adapter as a feature instead; see
[claude-agent-acp](../claude-agent-acp/notes.md).

`aoe acp doctor` is the diagnostic: it lists every configured agent as `[OK]` or
`[!!]` with the install hint. Only `claude`/`claude-code` are wired here — the
other adapters it lists (codex, gemini, opencode, …) stay `[!!]` on purpose.
The terminal view needs none of this; `aoe add` and the TUI default to it, and
Structured is the default only in the web dashboard.

Two gotchas the feature test ran into:

- `aoe acp doctor` **exits 2** whenever anything is less than fully OK, not just
  on hard errors ("Overall: partial"). The feature test therefore reads its
  output and ignores the status.
- doctor also reports `[!!] Node runtime not found` in the test VM, because
  `nodejs` isn't in this feature's `requires`. That's deliberate: `aoe` is a Rust
  binary and `claude-agent-acp` is a wrapper with node baked into the store path,
  so neither needs it. Only aoe's *bundled* `aoe-agent` (Vercel AI SDK) does —
  and both real hosts already enable `nodejs` in `system`. Add it to `requires`
  if that ever stops being true.
