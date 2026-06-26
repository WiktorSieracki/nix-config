---
name: remove-feature
description: Cleanly remove a feature from the nix-config — delete its self-contained folder and unwire it from every host, then verify nothing else broke. Use when the user wants to uninstall/remove software or a service from their NixOS config.
---

# /remove-feature

Remove a **feature**. Because features are self-contained, this is clean.

## Procedure

1. **Unwire from hosts:** remove `"<name>"` from the `modules` list of every host
   in `modules/hosts/*/default.nix` that enables it (grep for `"<name>"`).
2. **Delete the feature folder:** `git rm -r modules/features/.../<name>/`
   (removes module + `featureMeta` + Próba + `notes.md` in one go).
3. **Check for dangling requires:** if another feature declared `requires =
   [ ... "<name>" ... ]`, either that feature also needs removing/updating, or the
   dependency was real — surface it. `feature-coverage` will flag meta that names a
   non-existent feature.
4. **Verify:**
   - `nix build .#checks.x86_64-linux.feature-coverage` (consistency holds),
   - `nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`
     for each affected host (still evaluates; loader doesn't complain),
   - any `host-<host>` Próba still green.
5. **Apply (explicit):** `nh os switch --dry`, then `nh os test` / `nh os switch`.

## Notes
- If nothing else referenced the feature, removal touches only its own folder plus
  the host module lists — that self-containment is the whole point (docs/adr/0002).
