# Guide to Using Nix

## Introduction
Nix is a powerful package manager and build system that provides reproducible builds and declarative configurations. This guide will cover some essential topics to help you get started and make the most of Nix.

---

## Garbage Collection
Nix stores all packages and dependencies in the Nix store (`/nix/store`). Over time, this can consume a lot of disk space. To clean up unused packages, you can use garbage collection.

### Commands:
- **Run garbage collection:**
  ```bash
  nix-collect-garbage
  ```
- **Delete all unused paths:**
  ```bash
  nix-collect-garbage -d
  ```
- **Set up automatic garbage collection:** Add a cron job or systemd timer to periodically run `nix-collect-garbage`.

---

## Nix Version Control
Nix allows you to manage configurations declaratively using `.nix` files. You can version control these files using Git or other VCS tools.

### Steps:
1. **Initialize a Git repository:**
   ```bash
   git init
   ```
2. **Add your Nix files:**
   ```bash
   git add flake.nix home.nix modules/
   git commit -m "Initial commit of Nix configuration"
   ```
3. **Push to a remote repository:**
   ```bash
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

---

## Flakes
Flakes are a new feature in Nix that make it easier to manage reproducible configurations and dependencies.

### Key Commands:
- **Run a flake:**
  ```bash
  nix run .
  ```
- **Update flake inputs:**
  ```bash
  nix flake update
  ```
- **Check flake outputs:**
  ```bash
  nix flake show
  ```

### Example `flake.nix`:
```nix
{
  description = "My Nix Flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    defaultPackage.x86_64-linux =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
        };
      in pkgs.hello;
  };
}
```

---

## Additional Topics

### Nix Shell
Use `nix-shell` to create temporary development environments.
```bash
nix-shell -p <package>
```

### Nix Store
Inspect the Nix store to see installed packages:
```bash
nix-store --query --requisites /nix/store/<hash>
```

### Debugging
- **Dry-run a build:**
  ```bash
  nix-build --dry-run
  ```
- **Show derivation details:**
  ```bash
  nix show-derivation /nix/store/<hash>.drv
  ```

---

## Resources
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [Flakes Documentation](https://nixos.org/manual/nix/stable/#flakes)

---

This guide should help you get started with Nix and explore its powerful features.