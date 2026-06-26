# Dziennik: sending-cv

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: NIE przenosić sending-cv.nix — `default.nix` ma readFile ./form-at.sh

**Objaw**: przeniesienie `sending-cv.nix` do osobnego podfolderu nie psuje
samego sending-cv, ale `default.nix` obok używa `builtins.readFile ./form-at.sh`.  
**Przyczyna**: `modules/features/workspaces/default.nix` (który dodaje `form-at`
do `flake.modules.nixos.niri`) czyta `./form-at.sh` względnie. Folder jest
spójną całością.  
**Fix**: Cały folder `workspaces/` traktujemy jako monolityczną grupę.
Wyjątek od reguły folder-per-feature.

## Gotcha: `sending-cv` uruchamia niri msg — nie testowalne headless

**Objaw**: Próba sprawdza tylko, że binarny `sending-cv` jest na PATH. Faktyczne
działanie (otwieranie okien w konkretnych workspace'ach niri) wymaga działającej
sesji Wayland z niri.  
**Przyczyna**: `nixosTest` jest headless — brak sesji graficznej.  
**Fix**: Smoke test weryfikuje obecność binarnego. Integracyjne testy workspace'a
są wykonywane manualnie na desktopNixos.
