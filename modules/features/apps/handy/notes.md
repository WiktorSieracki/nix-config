# handy — Dziennik

2026-06-26: Dodano featureMeta + Próbę.

Feature używa `appimageTools.wrapType2` z osobno zinstancjonowanego nixpkgs (nie `pkgs` z perSystem) — jest to legacy pattern. Binarka to `handy`.

Objaw: `handy --start-hidden --no-tray` uruchamiany przez niri bind może nie działać w headless VM.
Przyczyna: AppImage wymaga środowiska graficznego (FUSE mount + Wayland/X11).
Fix: Próba sprawdza tylko obecność binarki na PATH (kind=gui), nie uruchamia procesu.

Objaw: AppImage może potrzebować `fuse` lub `fuse3` w runtime.
Przyczyna: appimageTools.wrapType2 montuje AppImage przez FUSE.
Fix: Na prawdziwej maszynie działa (nixos ma fuse). W VM headless nie jest testowany.
