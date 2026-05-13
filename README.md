# nix-config

Personal NixOS configuration using flakes, [flake-parts](https://github.com/hercules-ci/flake-parts), and [import-tree](https://github.com/vic/import-tree).

## Hosts

| Host | Description |
|------|-------------|
| `desktopNixos` | Primary desktop — NVIDIA GPU, Wacom tablet, full app set |
| `laptopNixos` | Laptop — Eduroam WiFi, lighter app set |

## Applying changes

```bash
# Dry-run (test without switching)
nh os switch --dry

# Apply
nh os switch
```

After applying, reload niri config without restarting (windows stay open):

```bash
niri msg action load-config-file

# Validate config without applying
niri validate
```

To build a specific host without switching:

```bash
nix build .#nixosConfigurations.desktopNixos.config.system.build.toplevel
nix build .#nixosConfigurations.laptopNixos.config.system.build.toplevel
```

Look up NixOS / home-manager options:

```bash
manix <option>
```

Update flake inputs:

```bash
nix flake update
```

## Structure

`flake.nix` imports everything under `./modules` via `import-tree` — there is no central `configuration.nix`. Each `.nix` file contributes to the flake by defining `flake.modules.*` attrsets.

```
modules/
├── hosts/
│   ├── configurations.nix        # mkSystems helpers, host assembly logic
│   ├── desktop-nixos/
│   │   ├── default.nix           # Feature list + NixOS configuration entry
│   │   └── hardware-configuration.nix
│   └── laptop-nixos/
│       ├── default.nix
│       └── hardware-configuration.nix
├── features/
│   ├── programming/              # git, fish, python, nodejs, java, docker, …
│   │   ├── editors/              # vscode, zeditor
│   │   └── AI/                   # llm-agents
│   ├── desktop/                  # niri, boot, sound, locale, terminal, …
│   ├── apps/                     # spotify, discord, bruno, …
│   ├── browsers/                 # firefox, brave
│   └── custom-scripts/           # gitHttpsToSsh, pull
├── meta.nix                      # Default terminal / browser / editor metadata
├── parts.nix                     # flake-parts + per-system nixpkgs
├── systems.nix                   # System list (x86_64-linux)
├── sops.nix                      # Secrets management
├── ssh.nix                       # SSH client (home-manager)
├── ssh-server.nix                # SSH server (NixOS)
└── tailscale.nix                 # VPN
```

Each host's `default.nix` holds a `modules` string list. Adding a name there enables both its `flake.modules.nixos.<name>` (system) and `flake.modules.homeManager.<name>` (user `wiktor`) configs.

## Secrets

Secrets are stored encrypted in `secrets.yaml` via [sops-nix](https://github.com/Mic92/sops-nix). Decryption requires `/home/wiktor/.ssh/id_ed25519`. Modules reference secrets with `sops.secrets.<name>` and `sops.templates.*`. Activation failures around sops are usually key/setup issues rather than module syntax errors.
