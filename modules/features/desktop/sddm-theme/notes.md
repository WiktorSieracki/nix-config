# sddm-theme — feature notes

## 2026-09-03 — split out of `desktop` as an opt-in toggle

The qylock "forest" greeter theme (video background) used to be hardwired into
the `desktop` feature. It is now its own feature so the greeter can be flipped
between native and themed by adding/removing `"sddm-theme"` from a host's
`features.json` `system` list. `desktop` alone gives the stock NixOS SDDM
greeter with no wallpaper (`services.displayManager.sddm.theme` left at its
default `""`).

Currently enabled on: no host (all hosts run the native greeter).

## Cursor

The cursor override (`settings.Theme.CursorTheme`) stays in `desktop`, not here:
the NixOS module only supplies a cursor for the breeze theme, so *any* other
value — including the empty default — leaves the greeter pointer invisible.
It is a greeter-wide fix, not part of this skin.

## Greeter changes need a reboot

`display-manager.service` is not restarted by a `nixos-rebuild switch`, so
toggling this feature only shows up after a reboot (or an explicit
`systemctl restart display-manager`, which kills the running session).
