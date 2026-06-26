# Dziennik: cursor-ide

Feature edytora Cursor IDE instalowanego przez HM jako `pkgs.code-cursor`.

## Gotchas

**2026-06-26** — Binarka nosi nazwę `cursor` (mainProgram nixpkgs `code-cursor`), nie `cursor-ide` ani `code-cursor`.
Próba asertuje `command -v cursor` przez `su - wiktor`.
