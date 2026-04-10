# Agent Rules

## Canonical commands
- Use `nh os switch` instead of `nixos-rebuild switch`.
- Test before applying with `nh os switch --dry`.
- For host-specific, non-switch verification, build directly: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` where `<host>` is `desktopNixos` or `laptopNixos`.

## Repo shape (flake-parts + import-tree)
- `flake.nix` imports everything from `./modules` via `import-tree`; there is no single `configuration.nix` entrypoint.
- Host assembly is defined in `modules/hosts/configurations.nix`.
- Enabled feature sets per machine are the `modules` lists in `modules/hosts/desktop-nixos/default.nix` and `modules/hosts/laptop-nixos/default.nix`.

## Secrets / sops gotchas
- Secrets come from `secrets.yaml` and are wired through `sops-nix` modules (`sops.nix`, `eduroam.nix`).
- Decryption expects `/home/wiktor/.ssh/id_ed25519` (`sops.age.sshKeyPaths`); sops-related eval/activation failures are often key/setup issues, not module syntax.

## Source-of-truth note
- `README.md` still documents an older Home Manager/WSL flow; for this repo use the flake NixOS host paths and commands above.
