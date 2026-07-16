# agent-of-empires — feature notes

2026-06-26: Added featureMeta + a feature test.

The feature uses the `aoe-with-web` package from the flake `github:agent-of-empires/agent-of-empires`.
Available packages: `default` (CLI/TUI only), `aoe-with-web` (with a web dashboard), `aoe-web-frontend`.
Main binary: `aoe` (meta.mainProgram = "aoe").

The feature also bundles `pkgs.tmux` because aoe manages sessions through tmux.
