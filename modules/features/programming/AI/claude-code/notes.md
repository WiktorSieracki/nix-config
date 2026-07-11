# claude-code — Dziennik

2026-07-11: Wydzielono z dawnego feature `llm-agents` (podzielonego na `claude-code`, `opencode`, `pi`).

Feature pobiera pakiet z zewnętrznego flake `github:numtide/llm-agents.nix`. Binarka: `claude-code` → `claude` (meta.mainProgram = "claude").

Objaw: Ewal może być wolny przy pierwszym budowaniu z powodu braku cache numtide.
Przyczyna: Flake numtide/llm-agents.nix reklamuje własne substitutory (`cache.numtide.com`), ale nie są one domyślnie zaufane.
Fix: Dodać `https://cache.numtide.com` do `nix.settings.substituters` lub budować lokalnie.
