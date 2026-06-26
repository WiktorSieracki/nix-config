# Dziennik: custom-scripts

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: NIE przenosić custom-scripts.nix — używa builtins.readFile ./...

**Objaw**: przeniesienie `custom-scripts.nix` do osobnego podfolderu psuje budowanie
feature'a z błędem "file not found".  
**Przyczyna**: moduł używa `builtins.readFile ./gitHttpsToSsh.sh` itd. — ścieżki
są względne do lokalizacji pliku `.nix`. Skrypty `.sh` muszą być obok.  
**Fix**: `custom-scripts.nix` + `*.sh` trzymamy w jednym folderze
`modules/features/custom-scripts/`. Wyjątek od reguły folder-per-feature.
