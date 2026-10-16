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

## 2026-10-16 — noctalia bar plugin + official CLI

Replaced the noctalia bar's local "Todo List" plugin (`plugin:todo`, a JSON
list on this machine only) with `plugin:todoist`, a plugin written here
(`noctalia-plugin/`) that reads and writes Todoist itself. Ticking a task on
the desktop completes it in Todoist, and the phone picks it up on its next
sync.

**CLI swap.** `sachaos/todoist` (`todoist`) is gone; the feature now ships
Doist's official `todoist-cli` (`td`). It has `--json` on every read
(`today`, `upcoming`, `inbox`), `task complete/uncomplete id:…`, and
natural-language `add`, which is everything the plugin needs. It reads
`TODOIST_API_TOKEN` or a token stored by `td auth login` (OAuth in the browser,
stored in the system keyring by default). The plugin's "Log in with Todoist"
button just runs `td auth login`. The token is not in SOPS. Without one, every
command exits 1 with `No API token found`, which the plugin (and the feature
test) key on.

**Plugin layout.** `todoist.js` is the logic: parsing, grouping, due labels,
error classification. It has no Qt imports, so `todoist.test.mjs` runs it under
node in the derivation's `checkPhase`, together with a `qmlformat` parse of
every QML file. A broken plugin fails the build instead of silently dropping
out of the bar. `Main.qml` owns state and spawns `td`. `BarWidget.qml` and
`Panel.qml` only bind to it. `td` and the app are substituted in as store paths
(`@td@`, `@todoistApp@`), because noctalia's PATH is whatever niri started with.

**Install path.** The noctalia wrapper's `preInstalledPlugins` would move
`NOCTALIA_CONFIG_DIR` into the read-only store, which breaks the runtime-
installed plugins (tailscale, mini-docker, …) and every plugin's settings.json.
So home-manager links the files one by one into
`~/.config/noctalia/plugins/todoist/` (`recursive = true`, so the directory is
real and writable). An activation step merges `states.todoist.enabled = true`
into `~/.config/noctalia/plugins.json`. noctalia ignores discovered plugins
that are not enabled there, and that file is runtime state it rewrites itself.

**After a rebuild** noctalia must be restarted to see the plugin or the new bar
slot: plugin discovery runs only at startup, and the bar layout comes from the
per-generation `NOCTALIA_SETTINGS_FILE` the running instance was launched with.

**The `todo` agent skill** moved here from `local-skills`. It now drives `td`
instead of `noctalia-ipc call plugin:todo`, and ships with the CLI it calls.
