# todoist — feature notes

2026-10-05: Added the feature — desktop app + CLI in one unit.

Two packages, one feature:

- `todoist-electron` — the official desktop app, repackaged from an AppImage
  (unfree). nixpkgs patches out the autoupdater, so it never tries to replace
  its own store path.
- `todoist` — the `sachaos/todoist` Go CLI, free.

`todoist-electron`'s own wrapper only passes `--ozone-platform-hint=auto` when
*both* `NIXOS_OZONE_WL` and `WAYLAND_DISPLAY` are set, and this config does not
set `NIXOS_OZONE_WL` globally. Hence the `symlinkJoin` wrapper that bakes it in
— the same workaround `discord` needs, and the reason the feature test greps for
the variable.

The CLI stores its API token in `~/.config/todoist/config.json` and prompts for
it on the first command that talks to the API (`todoist sync`). The token is not
managed by SOPS — nothing in this config writes that file, so the first run is
interactive. `todoist --help` works without it, which is what the feature test
asserts.

Keybind: `Mod+T` opens the app. It was previously `teams-for-linux`'s bind;
teams moved to `Mod+M` when this feature landed, because `flake.niriBinds` is
folded globally (every feature's binds reach niri's config whether or not a host
enables the feature), so two features claiming one chord resolve by attribute
order instead of by what is installed.
