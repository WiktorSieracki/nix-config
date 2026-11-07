# feature notes: zram

zram swap plus systemd-oomd on user slices, for the desktop and laptop. The VPS
sizes its own zram (`memoryPercent = 100`) in its hardware configuration.

## Gotchas

**2026-11-07** — `systemd.oomd.enable` is already `true` by default on NixOS,
but with no slice opted in it never kills anything. `enableUserSlices` is the
option that actually makes it act.
