# Dziennik: vscode

Feature edytora VS Code z profilem HM, rozszerzeniami (nix4vscode) i konfiguracją nixd LSP.

## Gotchas

**2026-06-26** — Rozszerzenia z `nix4vscode.forVscode [...]` to fixed-output derivations pobierane z VS Code Marketplace.
Objaw: Próba może nie zbudować się bez dostępu do internetu lub gdy rozszerzenia nie są w Cachix.
Przyczyna: `programs.vscode.profiles.default.extensions` materializuje się przy budowaniu nixos testu.
Fix: Próba używa `extraHmModules` z `lib.mkForce []` żeby wyzerować listę rozszerzeń — sprawdzamy tylko obecność binarki `code` na PATH.

**2026-06-26** — `vscode-insiders` i `vscode` nie mogą współistnieć w HM (`lib/vscode/` collision w buildEnv).
Przyczyna: oba pakiety dzielą ścieżki w `lib/vscode/`. VS Code Insiders jest dlatego instalowany jako system package, nie przez HM.
Fix: `vscode-insiders` korzysta z `environment.systemPackages`, a nie `programs.vscode`.
