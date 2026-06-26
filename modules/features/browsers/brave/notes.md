# Dziennik: brave

Feature przeglądarki Brave z rozszerzeniami konfigurowanymi przez HM (`programs.brave.extensions`).

## Gotchas

**2026-06-26** — `programs.brave.extensions` przyjmuje listy ID rozszerzeń Chrome Web Store (nie paczki nix).
Rozszerzenia te są pobierane przez samą przeglądarkę przy pierwszym uruchomieniu, nie przez nix — Próba nie musi ich stubować.
Binarka instalowana przez HM nosi nazwę `brave` (mainProgram z nixpkgs).
