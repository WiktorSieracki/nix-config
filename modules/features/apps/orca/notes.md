# orca — feature notes

Desktop client for [stablyai/orca](https://github.com/stablyai/orca) — an "ADE"
that runs a fleet of parallel coding agents (Claude Code, Codex, OpenCode, Pi),
each in its own git worktree.

## Packaging

- **No upstream nix package or flake.** Upstream ships prebuilt release
  artifacts only: `.AppImage`, `.deb`, `.rpm`, macOS `.dmg`, Windows `.exe`.
- We repackage the **`.deb`** (`orca-ide_<version>_amd64.deb`). It is a plain
  electron-builder tree at `/opt/Orca` with a bundled Electron, so
  `autoPatchelfHook` can link it against nixpkgs' own Chromium runtime libs.
  Preferred over `appimageTools` for the same reason as [buzz](../buzz/notes.md):
  the AppImage's FHS sandbox hides the host GPU drivers (`/run/opengl-driver`),
  which bites on NVIDIA.
- **Binary is `orca-ide`, not `orca`** — deliberate. `orca` in nixpkgs is the
  GNOME screen reader, and upstream's own binary is already named `orca-ide`.
- The `.desktop` file ships `Exec=/opt/Orca/orca-ide`; the install phase
  rewrites it to the wrapper name so it resolves via PATH.

## Runtime dependencies

The deb declares `python3, python3-gi, gir1.2-atspi-2.0, at-spi2-core, xdotool,
xclip, xvfb`. Those are for the **computer-use / agent-browser** features
(`resources/computer-use-linux`, `resources/agent-browser-linux-x64`), not for
the editor itself. `xdotool`, `xclip` and `xvfb` are put on the wrapper's PATH;
the AT-SPI/python3-gi side is only exercised by computer-use and is left out
until something actually needs it.

## Scope

This feature is only the desktop app. It does **not** install any coding agent —
Orca drives whatever `claude` / `codex` / etc. it finds on PATH, which come from
their own features.

## Updating the version

Bump `version` in `orca.nix`, then refresh the hash:

```bash
nix-prefetch-url https://github.com/stablyai/orca/releases/download/v<VERSION>/orca-ide_<VERSION>_amd64.deb
nix hash convert --hash-algo sha256 --to sri <BASE32_HASH>
```

Current: **v1.4.173** (released 2026-08-05). Upstream releases very frequently
(multiple times a day); the app has a built-in updater (`app-update.yml`) that
cannot work on NixOS, so bumping here is the only upgrade path.
