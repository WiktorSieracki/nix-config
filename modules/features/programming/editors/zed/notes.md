# feature notes: zeditor

*Last updated: 2026-06-26*

## Gotcha: the binary is `zeditor`, not `zed`

**Symptom**: `command -v zed` fails on NixOS — the `zed-editor` package exports the
binary as `zeditor` (`meta.mainProgram = "zeditor"`).
**Cause**: on Linux nixpkgs renamed the binary from `zed` to `zeditor` to avoid a
conflict with the `zed` package (a hex editor) in nixpkgs.
**Fix**: the feature test uses `command -v zeditor`.

## Gotcha: `./noctalia.json` — a path relative to the file next to .nix

**Symptom**: the theme file is loaded via `xdg.configFile."zed/themes/noctalia.json".source = ./noctalia.json`.
**Cause**: the path `./noctalia.json` is relative to `zeditor.nix`'s location.
**Fix**: do NOT move `zeditor.nix` without moving `noctalia.json` along with it. The
folder `modules/features/programming/editors/zed/` keeps both files together.
