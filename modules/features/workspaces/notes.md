# feature notes: sending-cv

*Last updated: 2026-06-26*

## Gotcha: do NOT move sending-cv.nix — `default.nix` has readFile ./form-at.sh

**Symptom**: moving `sending-cv.nix` into a separate subfolder doesn't break
sending-cv itself, but the `default.nix` next to it uses
`builtins.readFile ./form-at.sh`.
**Cause**: `modules/features/workspaces/default.nix` (which adds `form-at` to
`flake.modules.nixos.niri`) reads `./form-at.sh` relatively. The folder is a
coherent whole.
**Fix**: treat the whole `workspaces/` folder as one monolithic group. An exception
to the folder-per-feature rule.

## Gotcha: `sending-cv` runs niri msg — not headless-testable

**Symptom**: the feature test only checks that the `sending-cv` binary is on PATH.
The actual behaviour (opening windows in specific niri workspaces) needs a working
Wayland session with niri.
**Cause**: `nixosTest` is headless — there's no graphical session.
**Fix**: the smoke test verifies the binary is present. Integration tests of the
workspace behaviour are run manually on desktopNixos.
