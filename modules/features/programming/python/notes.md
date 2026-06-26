# Dziennik — python

## 2026-06-26

Objaw: `python3 --version` może nie znaleźć Pythona, jeśli zainstalowany jest `python314` bez wrappera `python3`.
Przyczyna: Nixpkgs `python314` instaluje `python3.14` i `python3` jako symlinki w tym samym derivation, więc `python3` powinien być na PATH.
Fix: Jeśli Próba failuje na `python3 --version`, zmienić asercję na `python3.14 --version` — to jest kanoniczny plik binarny paczki `python314`.
