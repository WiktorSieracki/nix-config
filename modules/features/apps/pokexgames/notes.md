# pokexgames — feature notes

## 2026-10-24 — packaging

- Download URL found in the support SPA's `partials/download` template
  (`https://support.pokexgames.com/partials/download`):
  `https://download.pokexgames.com/pxg-linux.zip` (Windows `pxg-setup.exe` sits
  next to it). The website itself only links `/signup`.
- The zip is **unversioned** — upstream overwrites it in place. When they do, a
  fresh build fails with a hash mismatch; refresh with
  `nix store prefetch-file https://download.pokexgames.com/pxg-linux.zip` and
  update `hash`. Installed machines are unaffected (the store path stays alive
  through the launcher), and an old zip is fine because it is only a bootstrap.
- The client self-updates into the directory it runs from (~870 MB after the
  first update vs ~100 MB in the zip), so it cannot run from the store. The
  launcher unpacks once into `$XDG_DATA_HOME/pokexgames` and runs from there;
  settings land in `mydata/`. Deleting that dir = clean reinstall.
- `pxgme-linux` is a glibc/SDL OTClient fork: NEEDED is only fontconfig + libc;
  GL/EGL/Vulkan, X11/Wayland, Pulse/ALSA, dbus and udev are dlopen'd (list via
  `strings pxgme-linux | grep '\.so'`), hence `buildFHSEnv` rather than
  autoPatchelf. Audio goes through a bundled OpenAL Soft.
- Verified on desktopNixos (niri, NVIDIA): window opens as app-id
  `pxgme-linux`, OGL2 painter on the RTX 4060 Ti, audio devices enumerated.
  The many `not found` texture/sound errors on the very first start are the
  pre-update asset set — the wiki says to restart the client after its first
  update.
- First login on a new machine sends an authorization email to the account's
  address (once per computer).
