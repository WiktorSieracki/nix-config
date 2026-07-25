# feature notes: niri

*Last updated: 2026-07-26*

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
