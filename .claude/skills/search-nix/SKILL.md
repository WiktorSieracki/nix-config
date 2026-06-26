---
name: search-nix
description: Find a package or NixOS/home-manager option in nixpkgs and the flake's inputs. Read-only lookup that feeds /install-feature and /update-feature. Use when you need to know the attribute/package/option name for something.
---

# /search-nix

Read-only discovery. Finds the real attribute names you'll reference in a feature.

## Procedure

1. **Packages:** `nix search nixpkgs <term>` (exact attr paths + descriptions).
   For the executable name a package installs, check `meta.mainProgram` /
   `lib.getExe`, or `ls $(nix build --no-link --print-out-paths nixpkgs#<pkg>)/bin`.
2. **Options:** `manix <option>` (NixOS + home-manager option docs). Or browse
   https://search.nixos.org/options.
3. **Flake inputs:** some programs come from inputs, not nixpkgs — check
   `flake.nix` inputs (e.g. `llm-agents`, `zed-editor`, `agent-of-empires`,
   `nix4vscode`, `spicetify-nix`) and their `packages.<system>.*`:
   `nix eval .#inputs.<name>.packages.x86_64-linux --apply builtins.attrNames`.

## Output
Report the candidate attribute path(s), the executable name, and whether it's a
nixpkgs package, a NixOS service option, a home-manager program, or a flake input.
This is the input to /install-feature.
