# Dziennik: firefox

Feature przeglądarki Firefox z profilem HM, zakładkami i rozszerzeniami z firefox-addons.

## Gotchas

**2026-06-26** — Rozszerzenia z `firefox-addons` to fixed-output derivations pobierane z addons.mozilla.org.
Objaw: `nix build .#checks.x86_64-linux.feature-firefox` kończy się błędem sieci lub timeoutem w środowisku sandboxed.
Przyczyna: `programs.firefox.profiles.wiktor.extensions.packages` próbuje pobrać rozszerzenia w czasie budowania VM testu.
Fix: Próba używa `extraHmModules` z `lib.mkForce []` żeby wyzerować listę rozszerzeń — sprawdzamy tylko obecność binarki `firefox` na PATH.
