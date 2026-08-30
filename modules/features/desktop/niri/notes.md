# feature notes: niri

*Last updated: 2026-08-29*

## Gotcha: noctalia IPC binds must not bake a store path (2026-08-22)

**Symptom**: after a few `nh os switch`, `Mod+Space`/`Mod+P` silently do nothing
while every other bind works; a fresh login fixes it.
**Cause**: the binds used to call `<store>/bin/noctalia-shell ipc …`. quickshell
matches the running instance by its `-p <pkg>/share/noctalia-shell` config path,
so an IPC client from another generation prints "No running instances" (exit
255) and niri ignores spawn-sh exit codes. The running noctalia is spawned once
at login and never restarted, while the loaded niri config can be newer (manual
`load-config-file --path …`) — the pair drifts.
**Fix**: binds and hooks go through `noctalia-ipc` (noctalia.nix), which greps
the running quickshell's `-p` path and execs *that* build's client — resolution
happens at invocation time, so client and instance can never diverge. Falls back
to `noctalia-shell` on PATH when no instance is running.

## Gotcha: screenshot-to-clipboard needs wl-clipboard for non-Wayland consumers

**Symptom** (2026-07-26): `Print` takes a screenshot and Wayland apps can paste
it, but pasting into Claude Code in the terminal yields nothing — it reports an
empty clipboard.
**Cause**: niri's screenshot action offers the PNG over the Wayland data-device
protocol, which only Wayland-native clients speak. Terminal programs shell out
to a CLI instead — Claude Code runs `wl-paste --type image/png`, falling back to
`xclip -selection clipboard -t image/png -o`. Neither binary was installed, so
the read failed silently and looked like "no picture in clipboard".
**Fix**: `wl-clipboard` is in the niri feature's `environment.systemPackages`,
asserted by the feature test. Note this is *not* a screenshot bug — the image
was on the clipboard the whole time; only the reader was missing.

## Gotcha: the feature test doesn't start the compositor (no GPU in the VM)

**Symptom**: a headless `nixosTest` can't display a Wayland session — the VM
starts without a GPU, and `niri` launched as a program crashes.
**Cause**: niri needs a working Wayland EGL / GPU.
**Fix**: the feature test only checks that the `niri` binary is on PATH (the
package installed by `programs.niri.enable`). Full compositor smoke tests need
`virtio-vga-gl` and are done manually by a human (the `vm` host).

## Gotcha: myNiri depends on niriBinds and myNoctalia

**Symptom**: evaluating the niri feature requires `flake.niriBinds` and
`self'.packages.myNoctalia` to be defined.
**Cause**: perSystem in niri.nix builds `myNiri` via wrapper-modules, which merges
all `flake.niriBinds` and embeds the path to myNoctalia.
**Fix**: featureMeta.niri has `requires = []` — both attributes are available
through the flake-parts merge (niriBinds from many files, myNoctalia from
noctalia.nix) and need no explicit `requires`.

## Gotcha: ScreenCast portal must be gnome, not wlr (2026-08-06)

**Symptom**: any screen share (Discord, Firefox `getDisplayMedia`) delivers a
single frozen frame instead of live video.
**Cause**: `xdg.portal.config.niri` routed
`org.freedesktop.impl.portal.ScreenCast` to `wlr`. xdg-desktop-portal-wlr talks
wlr-screencopy, and on niri the resulting stream never advances past its first
frame. This override also deviated from the nixpkgs niri module's default
(`gnome`).
**Fix**: route ScreenCast to `gnome` and add `xdg-desktop-portal-gnome` to
`extraPortals`. niri implements the `org.gnome.Mutter.ScreenCast` D-Bus API for
exactly this backend (`busctl --user list | grep Mutter` shows niri owning it).
Screenshot stays on `wlr` deliberately — it grabs without an interactive picker,
which the gnome backend would force.
Full context, including the Electron/XWayland half of the same bug, is in
`modules/features/apps/discord/notes.md`.

## Gotcha: keep-awake is runtime-only state, re-armed by the startup hook (2026-08-29)

**Symptom**: the machine dims the screens after 10 min and locks after 11 min
(`idle.screenOffTimeout` / `lockTimeout`), and the KeepAwake toggle that stops it
has to be clicked again after every login.
**Cause**: noctalia's manual idle inhibitor lives in `IdleInhibitorService`'s
`activeInhibitors` list only — there is no `settings.json` key for it, so a
declarative wrapper-modules setting cannot express "start inhibited". While
active, the shell binds a native Wayland `IdleInhibitor` per screen, which stops
niri's `ext-idle-notify-v1` clock and therefore `IdleService` entirely.
**Fix**: `hooks.startup` (noctalia.nix) calls `noctalia-ipc call idleInhibitor
enable` after pinning the wallpaper, so every session starts inhibited; the bar /
control-center toggle still turns it off for the rest of the session. The idle
timeouts are deliberately left enabled so that toggle has something to re-arm.
