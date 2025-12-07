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
   nix-shell -p home-manager --command "home-manager switch --flake .#wiktor@desktop-wsl"
   ```

## 🖥️ Host Configurations

### Desktop WSL (`desktop-wsl/`)

Configuration optimized for Windows Subsystem for Linux environment with development tools and productivity applications. This is currently the main configuration defined in the flake.

## 📦 Included Applications & Tools

The configuration includes a curated set of development tools and applications:

### Development Tools
- **Node.js & Package Managers**: Node.js 25, pnpm (with npm aliased to pnpm)
- **Java**: Zulu JDK 25
- **Python**: Python 3.12 with packages:
  - numpy, pandas, matplotlib, scipy
  - opencv4, scikit-image
  - pygame, requests
  - pyautogui
- **Python Tools**: uv, ruff
- **Scala**: Scala, SBT, Scalafmt

### Editor & Shell
- **Editor**: Neovim (via nixvim) with Gruvbox colorscheme and LSP support
- **Shell**: Fish shell with custom prompts and plugins:
  - z (directory jumping)
  - fish-ssh-agent (automatic SSH key management)
  - Vi mode enabled
  - Custom `nix-fish` function for temporary nix shells

### Version Control & SSH
- **Git**: Configured with user details and SSH authentication
- **SSH**: Automatic configuration for GitHub and GitLab

### Utilities
- **Nix Tools**: alejandra (formatter), nix-search-cli
- **File Tools**: tree, treecat
- **Documentation**: tealdeer (tldr pages)
- **Development**: pre-commit hooks

### Custom Scripts
- **`gitHttpsToSsh`**: Convert Git remotes from HTTPS to SSH
- **`pull`**: Recursively pull updates for all Git repositories in current directory

### Shell Aliases
- `npx` → `pnpx`
- `npm` → `pnpm`
- `nnpm` → `npm` (access to original npm)
- `nnpx` → `npx` (access to original npx)
- `winuv` → Windows UV executable (for Python on Windows from WSL)

## 📖 Documentation

For detailed Nix usage information, see [nix-guide.md](./nix-guide.md) which covers:

- Garbage collection
- Version control best practices
- Flakes usage
- Package management
- Troubleshooting

## 🔄 Updating Configuration

1. **Make changes** to the appropriate `.nix` files in [modules/](modules/) or [home/](home/)

2. **Test changes**:

   ```bash
   home-manager switch --flake .#wiktor@desktop-wsl --dry-run
   ```

3. **Apply changes**:

   ```bash
   home-manager switch --flake .#wiktor@desktop-wsl
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

Then apply the updated configuration:

```bash
home-manager switch --flake .#wiktor@desktop-wsl
```

## 📁 Configuration Structure

```
├── flake.nix                 # Main flake configuration
├── home/
│   ├── shared.nix           # Shared configuration across all hosts
│   └── desktop-wsl/
│       └── home.nix         # WSL-specific configuration
├── modules/
│   ├── git.nix              # Git configuration
│   ├── java.nix             # Java (Zulu JDK)
│   ├── nixvim.nix           # Neovim configuration
│   ├── python.nix           # Python environment
│   ├── ssh.nix              # SSH configuration
│   ├── fish/                # Fish shell configuration
│   └── magisterka/
│       └── scala.nix        # Scala toolchain
└── customScripts/           # Custom utility scripts
```

## 🔧 Development Tools Integration

### Fish Shell Features
- Automatic SSH key loading (`~/.ssh/id_ed25519`)
- Java environment automatically set
- Disco theme prompt
- Nix shell indicator in prompt
- Smart directory navigation with z plugin

### Java Development
The Java home is automatically set to the Zulu JDK. To find the exact path:

```bash
readlink -f $(which java)
```

### Python Development
Python 3.12 is configured with common data science and automation packages. Use `uv` for additional package management.

### WSL-Specific Features
- X11 forwarding enabled (`DISPLAY=:0`)
- Generic Linux target enabled for better WSL compatibility

## 🤝 Contributing

This is a personal configuration, but feel free to fork and adapt for your own use.

## 📄 License

This configuration is provided as-is for educational and personal use. Feel free to use and modify as needed.