# feature notes: firefox

The Firefox browser feature with an HM profile, bookmarks and extensions from firefox-addons.

## Gotchas

**2026-06-26** — Extensions from `firefox-addons` are fixed-output derivations fetched from addons.mozilla.org.
Symptom: `nix build .#checks.x86_64-linux.feature-firefox` fails with a network error or timeout in a sandboxed environment.
Cause: `programs.firefox.profiles.wiktor.extensions.packages` tries to fetch the extensions while building the VM test.
Fix: The feature test uses `extraHmModules` with `lib.mkForce []` to zero out the extension list — we only check that the `firefox` binary is on PATH.
