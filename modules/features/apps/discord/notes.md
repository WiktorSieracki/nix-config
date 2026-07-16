# discord — feature notes

2026-06-26: Added featureMeta + a feature test.

Symptom: `command -v discord` returns "not found" despite the package being installed.
Cause: The upstream nixpkgs package exposes the binary as `Discord` (capital D), not `discord`.
Fix: The feature test asserts `command -v Discord`. The package is unfree, but `allowUnfree = true` is already set in the perSystem pkgs (modules/parts.nix) and propagates to the VM test — no need to add extraNixosModules (trying to add `nixpkgs.config.allowUnfree` in an extra module fails with "config is read-only").
