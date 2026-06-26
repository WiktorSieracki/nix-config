# discord — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Objaw: `command -v discord` zwraca „not found" mimo zainstalowanego pakietu.
Przyczyna: Upstream pakiet nixpkgs eksponuje binarke jako `Discord` (wielka litera D), nie `discord`.
Fix: Próba asertuje `command -v Discord`. Pakiet jest unfree, ale `allowUnfree = true` jest już ustawione w perSystem pkgs (modules/parts.nix) i propaguje do VM testu — nie trzeba dodawać extraNixosModules (próba dodania `nixpkgs.config.allowUnfree` w extra module skutkuje błędem „config is read-only").
