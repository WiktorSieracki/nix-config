# feature notes: nix

*Last updated: 2026-07-09*

## Gotcha: `nix shell nixpkgs#pkg` still needs `--impure` for unfree

**Symptom**: even though `nixpkgs.config.allowUnfree = true` is set in this feature,
`nix shell nixpkgs#obsidian` and other commands that reference `nixpkgs#...`
directly (rather than packages from this flake) still reject unfree.
**Cause**: system-level `allowUnfree` applies only to packages built *by this flake*
(systemPackages, home.packages). Ad hoc `nix shell`/`nix run nixpkgs#...` evaluates
`legacyPackages` from a separate, pure invocation of the nixpkgs flake, which
doesn't see the system config.
**Fix**: added `NIXPKGS_ALLOW_UNFREE=1` to `environment.sessionVariables`. Legacy
`nix-shell -p`/`nix-env` are impure by default, so they see this variable right
away. Flake commands (`nix shell/run nixpkgs#...`) still need a manual `--impure`,
because flakes are pure by default and don't read environment variables without that
flag — there's no declarative way around it for ad hoc references to `nixpkgs#...`
outside this flake.

**Note**: an attempt to add `flake.modules.homeManager.nix` (to write
`~/.config/nixpkgs/config.nix`) broke host validation — `nix` is a `system` feature
(shared by `wiktor` and `work`), and the HM half of a feature can only attach to
per-user features.

## Gotcha: the `nix` binary is part of Core, not this feature

**Symptom**: the assertion `nix --version` may be a false positive — `nix` comes from
the Core floor, not from this feature.
**Cause**: NixOS always has `nix` installed as part of the system.
**Fix**: the feature test asserts `alejandra --version` and `nh --version`, which are
actually added by this feature to `environment.systemPackages`.
