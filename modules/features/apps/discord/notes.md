# discord — feature notes

2026-06-26: Added featureMeta + a feature test.

Symptom: `command -v discord` returns "not found" despite the package being installed.
Cause: The upstream nixpkgs package exposes the binary as `Discord` (capital D), not `discord`.
Fix: The feature test asserts `command -v Discord`. The package is unfree, but `allowUnfree = true` is already set in the perSystem pkgs (modules/parts.nix) and propagates to the VM test — no need to add extraNixosModules (trying to add `nixpkgs.config.allowUnfree` in an extra module fails with "config is read-only").

## Gotcha: screen sharing streams a still image (2026-08-06)

**Symptom**: starting a screen share in Discord shows the viewer one frozen
screenshot of the desktop instead of live video.

**Cause**: two independent faults stacked, and fixing either alone is not enough.

1. Discord was running on XWayland, not Wayland. nixpkgs' wrapper gates the
   Ozone flags behind an environment variable:
   ```
   exec ... ${NIXOS_OZONE_WL:+${WAYLAND_DISPLAY:+--ozone-platform=wayland ...}}
   ```
   Nothing in this config sets `NIXOS_OZONE_WL`, so Electron fell back to X11
   and captured the `xwayland-satellite` root window — which never composites
   Wayland-native windows and does not refresh.
2. The ScreenCast portal was routed to `xdg-desktop-portal-wlr` (an override in
   `modules/features/desktop/niri/niri.nix`, deviating from the nixpkgs niri
   default of `gnome`). On niri, xdpw's wlr-screencopy stream does not advance
   past its first frame.

**Fix**: `mkDiscord` wraps `pkgs.discord` with `--set NIXOS_OZONE_WL 1`, so both
the `Mod+D` niri bind and the `.desktop` entry (`Exec=Discord`, resolved off
PATH) get a Wayland-native session; and the niri feature routes
`org.freedesktop.impl.portal.ScreenCast` to `gnome`. niri owns the
`org.gnome.Mutter.ScreenCast` D-Bus name specifically so that
xdg-desktop-portal-gnome works — verify with `busctl --user list | grep Mutter`.

**Diagnosis order that worked**: check `/proc/<pid>/cmdline` of the Discord
renderer for `--ozone-platform=wayland` (absent ⇒ fault 1), then check
`/etc/xdg/xdg-desktop-portal/niri-portals.conf` for the ScreenCast backend
(`wlr` ⇒ fault 2). Both can be tested live before a rebuild: relaunch with
`NIXOS_OZONE_WL=1 Discord`, and shadow the portal routing via
`~/.config/xdg-desktop-portal/niri-portals.conf` + `systemctl --user restart
xdg-desktop-portal.service`. Remember to delete that user-level file afterwards,
or it silently masks the Nix-managed config.

**Still open**: the other Electron apps in this config (obsidian, affine, bruno,
teams-for-linux) are still on XWayland for the same reason and would hit fault 1
if they ever need to capture the screen.
