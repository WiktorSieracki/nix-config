# feature notes: custom-scripts

*Last updated: 2026-06-26*

## Gotcha: do NOT move custom-scripts.nix — it uses builtins.readFile ./...

**Symptom**: moving `custom-scripts.nix` into a separate subfolder breaks the
feature build with a "file not found" error.
**Cause**: the module uses `builtins.readFile ./gitHttpsToSsh.sh` etc. — the
paths are relative to the `.nix` file's location. The `.sh` scripts must sit
next to it.
**Fix**: keep `custom-scripts.nix` + `*.sh` in one folder,
`modules/features/custom-scripts/`. An exception to the folder-per-feature rule.
