# playwright — feature notes

- **2026-07-02** Playwright on NixOS can't download browsers itself (the binaries
  assume FHS). The feature sets `PLAYWRIGHT_BROWSERS_PATH` to
  `pkgs.playwright-driver.browsers` and
  `PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true`
  (per https://nixos.wiki/wiki/Playwright).
- **2026-07-02** `home.sessionVariables` isn't enough on its own: it lands in
  `hm-session-vars.sh` (with `useUserPackages=true` →
  `/etc/profiles/per-user/wiktor/etc/profile.d/`), sourced only by HM-managed shells.
  The minimal feature-test VM (core+wiktor, without the `fish` feature) doesn't
  source it → the variable is empty in `su - wiktor`. That's why the `playwright`
  binary is wrapped (`--set-default`) and works from any context.
- **2026-07-02** In npm projects the version of the `@playwright/test` package
  **must match the nixpkgs version** (currently 1.60.0), because the browser
  revisions in `PLAYWRIGHT_BROWSERS_PATH` are matched to that driver version. On
  `npm install` it's worth setting `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`.
