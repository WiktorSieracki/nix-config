# waydroid

- 2026-09-27: NVIDIA GPUs are not supported for Waydroid's hardware rendering (needs
  Mesa). On desktopNixos the AMD iGPU (RADV, Ryzen 7800X3D) can be used instead, or
  software rendering (`ro.hardware.gralloc=default`, `ro.hardware.egl=swiftshader`).
- First-time setup is imperative: `sudo waydroid init -s GAPPS` downloads the Android
  image into /var/lib/waydroid; then `waydroid session start` + `waydroid show-full-ui`.
- 2026-09-27: `waydroid session start` failed in `waydroid-net.sh start` with
  "Module ip_tables not found": the script picks `iptables-legacy`, and this kernel has
  no legacy `ip_tables` module. Fixed by patching the script to use `iptables-nft`.
- 2026-09-27: GPU auto-selection skips nvidia and uses the AMD iGPU (renderD129,
  radeonsi) — no `drm_device` needed. Imperative per-install state (in /var/lib/waydroid,
  not declarative): `auto_adb = True` in waydroid.cfg, `persist.waydroid.width/height`
  props for a portrait 540x960 screen (Clash Royale bot), host adb key appended to
  /data/misc/adb/adb_keys, and the GSF android_id registered at
  google.com/android/uncertified for Play Store sign-in.
- 2026-09-27: `adb exec-out screencap` output starts with a Mesa warning
  ("amdgpu.ids: No such file or directory") before the raw header — parsers must skip it.
