# playwright — Dziennik

- **2026-07-02** Playwright na NixOS nie może sam pobierać przeglądarek (binarki
  zakładają FHS). Feature ustawia `PLAYWRIGHT_BROWSERS_PATH` na
  `pkgs.playwright-driver.browsers` i `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true`
  (za https://nixos.wiki/wiki/Playwright).
- **2026-07-02** `home.sessionVariables` nie wystarcza samo w sobie: trafia do
  `hm-session-vars.sh` (przy `useUserPackages=true` →
  `/etc/profiles/per-user/wiktor/etc/profile.d/`), source'owanego tylko przez
  shelle zarządzane przez HM. Minimalna VM Próby (core+wiktor, bez feature'a
  `fish`) go nie source'uje → zmienna pusta w `su - wiktor`. Dlatego binarka
  `playwright` jest wrapowana (`--set-default`) i działa z każdego kontekstu.
- **2026-07-02** W projektach npm wersja pakietu `@playwright/test` **musi zgadzać
  się z wersją z nixpkgs** (obecnie 1.60.0), bo revisiony przeglądarek w
  `PLAYWRIGHT_BROWSERS_PATH` są dobrane do tej wersji drivera. Przy
  `npm install` warto ustawić `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`.
