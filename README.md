# Home Manager Configuration

This repository contains my personal [Home Manager](https://github.com/nix-community/home-manager) configuration using Nix flakes for declarative user environment management.

## 🚀 Quick Start

### First Time Setup

Run the provided setup script to install Nix and apply the Home Manager configuration:

```bash
./start.sh
```

This script will:

1. Install Nix using the Determinate Systems installer
2. Source the Nix environment
3. Apply the Home Manager configuration with backup

### Manual Setup

If you prefer manual setup:

1. **Install Nix** (if not already installed):

   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
   ```

2. **Source Nix environment**:

   ```bash
   . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
   ```

3. **Apply configuration**:

   ```bash
   nix-shell -p home-manager --command "home-manager switch -b backup --impure"
   ```

## 🖥️ Host Configurations

### Desktop WSL (`desktop-wsl/`)

Configuration optimized for Windows Subsystem for Linux environment with development tools and productivity applications.

### Laptop NixOS (`laptop-nixos/`)

Full NixOS system configuration including hardware-specific settings and additional system-level configurations like fingerprint authentication.

## 📦 Included Applications & Tools

The configuration includes a curated set of development tools and applications:

- **Development**: Node.js, Angular CLI, Java, Python
- **Editor**: Neovim (via nixvim), VS Code
- **Shell**: Fish shell with custom prompts
- **Browser**: Firefox with custom configuration
- **Version Control**: Git with SSH configuration
- **Document Preparation**: Typst
- **Utilities**: Tree, pre-commit hooks, custom scripts

## 🔧 Management Commands

Use the included custom scripts for easier management:

- **`manage`**: Wrapper for Home Manager operations
- **`pull`**: Git pull utility for configuration updates
- **`gitHttpsToSsh`**: Convert Git remotes from HTTPS to SSH

## 📖 Documentation

For detailed Nix usage information, see [`nix-guide.md`](./nix-guide.md) which covers:

- Garbage collection
- Version control best practices
- Flakes usage
- Package management
- Troubleshooting

## 🔄 Updating Configuration

1. **Make changes** to the appropriate `.nix` files
2. **Test changes**:

   ```bash
   home-manager switch --dry-run
   ```

3. **Apply changes**:

   ```bash
   home-manager switch
   ```

4. **Commit changes**:

   ```bash
   git add .
   git commit -m "Update configuration"
   git push
   ```

## 🧹 Maintenance

### Garbage Collection

Clean up unused packages periodically:

```bash
nix-collect-garbage -d
```

### Update Flake Inputs

Update to latest package versions:

```bash
nix flake update
```

## 🤝 Contributing

This is a personal configuration, but feel free to fork and adapt for your own use

## 📄 License

This configuration is provided as-is for educational and personal use. Feel free to use and modify as needed.
