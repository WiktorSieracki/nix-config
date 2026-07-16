---
name: update-feature
description: Modify an existing feature in the nix-config (change its config, bump a flake input it uses, add/remove a package) and re-verify it in a VM before applying. Use when the user wants to change/upgrade/reconfigure software already in their config.
---

# /update-feature

Change an existing **feature** and re-prove it green before metal.

## Procedure

1. **Locate** the feature: `modules/features/.../<name>/<name>.nix`. Read its
   `notes.md` (feature notes) for known gotchas.
2. **Make the change** — edit the module (config/package), or bump the flake input
   it pulls from (`nix flake update <input>` for an input-backed feature).
3. **Keep meta honest:** if the change adds/removes a dependency, update
   `featureMeta.<name>.requires`. If behaviour changes, update the
   `featureTests.<name>.testScript` assertions to match the new expectation.
4. **Re-green:** run **/nix-loop** for `<name>`. Also rebuild any host feature test that
   exercises it (`nix build .#checks.x86_64-linux.host-<host>` if present) so the
   e2e path still holds.
5. **Apply (explicit, outside the loop):** `nh os switch --dry`, then `nh os test`
   / `nh os switch` per the user.

## Notes
- If you turned a previously-uncaught failure into a reproducible one, encode it as
  a new testScript assertion (regression guard); put only non-executable wisdom in
  `notes.md`.
- A bumped input may change a binary's name/path — re-check with /search-nix.
