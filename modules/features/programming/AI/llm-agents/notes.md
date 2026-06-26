# llm-agents — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Feature pobiera pakiety z zewnętrznego flake `github:numtide/llm-agents.nix`. Binarne nazwy:
- `claude-code` → binarka `claude` (meta.mainProgram = "claude")
- `opencode` → binarka `opencode`
- `omp` → binarka `omp`

Objaw: Ewal może być wolny przy pierwszym budowaniu z powodu braku cache numtide.
Przyczyna: Flake numtide/llm-agents.nix reklamuje własne substitutory (`cache.numtide.com`), ale nie są one domyślnie zaufane.
Fix: Dodać `https://cache.numtide.com` do `nix.settings.substituters` lub budować lokalnie.
