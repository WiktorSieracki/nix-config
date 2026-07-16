# feature notes: niri

*Last updated: 2026-06-26*

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
