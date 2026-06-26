# spotify — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Feature używa wyłącznie `homeManager.spotify` (brak modułu nixos) — wymaga `["wiktor"]`.
Spicetify-nix opakowuje binarke Spotify i udostępnia ją jako `spotify` w profilu HM użytkownika.
Próba wymaga `nixpkgs.config.allowUnfree = true` w ekstra-modulach VM — spotify jest unfree.

Objaw: Ocena VM może się zawiesić jeśli spicetify próbuje pobrać zasoby z internetu w czasie aktywacji HM.
Przyczyna: Spicetify podczas `home-manager-wiktor.service` może próbować połączyć się z CDN Spotify.
Fix: Na razie nie zaobserwowano w testach headless; jeśli wystąpi, dodać `networking.firewall.allowedTCPPorts` lub stub HTTP serwer.
