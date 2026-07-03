# Listy feature'ów hostów w plikach danych (features.json), nie w Nixie

Prawdziwe hosty (`desktopNixos`, `laptopNixos`) trzymają swoją listę feature'ów
w `modules/hosts/<host>/features.json` (płaska lista nazw), czytanej przez
`default.nix` via `builtins.fromJSON`. Powód: lista musi być *zapisywalna* przez
zewnętrzne narzędzie (**Switchboard**, TUI do włączania feature'ów), a edycja
składni Nix z zewnątrz jest wiecznie krucha (komentarze, formatowanie).
Odrzucone alternatywy: parsowanie/edycja `.nix` przez CLI oraz jeden globalny
`hosts.json` (łamałby symetrię folder-per-host). Koszt: znikają sekcyjne
komentarze-kategorie w listach (świadomie zaakceptowany). Hosty obrazowe
(`iso`, `vm`) zostają przy listach inline — nie są celem Switchboarda.
Walidacja `requires` pozostaje w loaderze (ADR 0002) — plik danych niczego
nie auto-dociąga; Switchboard zapisuje domknięcie jawnie.
