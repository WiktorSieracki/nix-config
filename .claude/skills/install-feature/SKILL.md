---
name: install-feature
description: Add a new standalone feature (package/program/service) to the nix-config — scaffold the module + featureMeta + feature test + feature notes, drive it green in a VM, then wire it into a host. Use when the user wants to install/add software or a service to their NixOS config.
---

# /install-feature

Create a new self-contained **feature** and prove it works before touching metal.

## Procedure

1. **Find it:** run /search-nix for the package/option → attribute path, exe name,
   and whether it's a nixpkgs package / NixOS service / home-manager program /
   flake input.
2. **Scaffold** `modules/features/<category>/<name>/<name>.nix` (folder-per-feature):
   ```nix
   {inputs, ...}: {
     flake.modules = {
       # nixos.<name>  = {pkgs, ...}: { ... };       # system pkg/service
       # homeManager.<name> = {pkgs, ...}: { ... };  # user program/config
     };

     flake.featureMeta.<name> = {
       requires = [ /* "wiktor" if it has a homeManager part; "desktop" if it
                       needs the niri session; another feature if it depends on
                       one (declare it — the loader hard-fails otherwise) */ ];
       kind = "cli";   # cli | config | service | gui
     };

     flake.featureTests.<name> = {
       testScript = ''
         machine.wait_for_unit("multi-user.target")
         machine.wait_for_unit("home-manager-wiktor.service")   # HM features only
         machine.succeed("su - wiktor -c 'command -v <exe>'")   # or a real smoke
       '';
       # extraNixosModules / extraHmModules = [...];  # e.g. SOPS stub
     };
   }
   ```
   Model it on `modules/features/programming/git/git.nix` (a SOPS-backed example).
   For GUI apps, assert the binary is installed rather than launching a window.
3. **feature notes:** create `modules/features/<category>/<name>/notes.md` with a header.
4. **Track it:** `git add` the new folder (flakes ignore untracked files).
5. **Green it:** run **/nix-loop** for `<name>` until the feature test passes.
6. **Wire into a host:** ask which host (default `desktopNixos`); add `"<name>"`
   to that host's `modules` list in `modules/hosts/<host>/default.nix`. Ensure all
   of the feature's `requires` are also enabled on that host — the loader
   hard-fails otherwise (that error message tells you exactly what's missing).
7. **Apply to metal (explicit, OUTSIDE the loop):** `nh os switch --dry`, then
   tell the user to run `nh os test` / `nh os switch` (or do it if they ask).
   Never switch the real system inside the loop.

## Guardrails
- One feature = one folder, self-contained: declare every dependency in `requires`;
  no hidden cross-file coupling. See CONTEXT.md (glossary) and docs/adr/0002.
