# handy — feature notes

2026-06-26: Added featureMeta + a feature test.

The feature uses `appimageTools.wrapType2` from a separately instantiated nixpkgs (not the perSystem `pkgs`) — this is a legacy pattern. The binary is `handy`.

Symptom: `handy --start-hidden --no-tray` launched via a niri bind may not work in a headless VM.
Cause: The AppImage needs a graphical environment (FUSE mount + Wayland/X11).
Fix: The feature test only checks the binary is on PATH (kind=gui), it does not start the process.

Symptom: The AppImage may need `fuse` or `fuse3` at runtime.
Cause: appimageTools.wrapType2 mounts the AppImage via FUSE.
Fix: Works on the real machine (nixos has fuse). Not tested in the headless VM.
