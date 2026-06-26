# Dziennik: zeditor

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: binarny jest `zeditor`, nie `zed`

**Objaw**: `command -v zed` failuje na NixOS — pakiet `zed-editor` eksportuje
binarny jako `zeditor` (`meta.mainProgram = "zeditor"`).  
**Przyczyna**: Na Linuxie nixpkgs zmienił nazwę binarnego z `zed` na `zeditor`
żeby uniknąć konfliktu z pakietem `zed` (hex editor) z nixpkgs.  
**Fix**: Próba używa `command -v zeditor`.

## Gotcha: `./noctalia.json` — ścieżka względna do pliku obok .nix

**Objaw**: plik motywu jest ładowany przez `xdg.configFile."zed/themes/noctalia.json".source = ./noctalia.json`.  
**Przyczyna**: ścieżka `./noctalia.json` jest względna do lokalizacji `zeditor.nix`.  
**Fix**: NIE przenosić `zeditor.nix` bez przenoszenia `noctalia.json` razem. Folder
`modules/features/programming/editors/zed/` trzyma oba pliki razem.
