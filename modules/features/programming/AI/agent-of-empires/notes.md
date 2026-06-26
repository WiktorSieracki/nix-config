# agent-of-empires — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Feature używa pakietu `aoe-with-web` z flake `github:agent-of-empires/agent-of-empires`.
Dostępne pakiety: `default` (CLI/TUI only), `aoe-with-web` (z dashboardem webowym), `aoe-web-frontend`.
Binarka główna: `aoe` (meta.mainProgram = "aoe").

Feature dołącza też `pkgs.tmux` bo aoe zarządza sesjami przez tmux.
