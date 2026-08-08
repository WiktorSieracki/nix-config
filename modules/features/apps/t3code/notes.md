# t3code — feature notes

Desktop client for [pingdotgg/t3code](https://github.com/pingdotgg/t3code) — an
"agent harness control surface" that drives coding agents (Claude Code, Codex,
Cursor, Grok Build, OpenCode) running on this machine, from the desktop app, a
web app or the mobile apps.

## Packaging

- **No upstream nix package or flake.** Upstream ships prebuilt artifacts only:
  Linux `.AppImage`, macOS `.dmg`/`.zip`, Windows `.exe`. There is **no `.deb`**,
  so unlike [orca](../orca/notes.md) we cannot repackage a debian tree.
- We unpack the AppImage with `appimageTools.extract` and then treat the
  contents exactly like orca's `/opt/Orca`: a plain electron-builder tree with a
  bundled Electron, linked against nixpkgs' libs by `autoPatchelfHook`.
- **Not `appimageTools.wrapType2`** — its FHS sandbox hides the host GPU drivers
  (`/run/opengl-driver`), which bites on NVIDIA. Same reasoning as
  [buzz](../buzz/notes.md) and orca.
- `appendRunpaths = [libglvnd]` for the same ANGLE `dlopen("libEGL.so.1")` trap
  documented at length in [orca's notes](../orca/notes.md#2026-08-06--gpu-process-died-on-start-libeglso1-not-found):
  `dlopen` resolves against the runpath of the *calling library*, so the bundled
  `libEGL.so` needs libglvnd on its own runpath, and `runtimeDependencies` does
  not reach it.
- The AppImage's `.desktop` ships `Exec=AppRun --no-sandbox %U`. `AppRun` only
  bootstraps the AppImage mount, so it is deleted and the entry rewritten to the
  `t3code` wrapper. We also drop `--no-sandbox`: NixOS has unprivileged user
  namespaces, so Electron's namespace sandbox works without the setuid
  `chrome-sandbox`.

## Scope

This feature is only the desktop app. It installs **no coding agent** — t3code
drives whatever `claude` / `codex` / etc. it finds on PATH, which come from their
own features. `npx t3@latest` (the headless server + local web app) is a separate
entrypoint we do not package.

## Updating the version

Bump `version` in `t3code.nix`, then refresh the hash:

```bash
nix store prefetch-file --hash-type sha256 \
  https://github.com/pingdotgg/t3code/releases/download/v<VERSION>/T3-Code-<VERSION>-x86_64.AppImage
```

Current: **v0.0.31**. Upstream also publishes `*-nightly.*` prereleases several
times a day; we track the stable tags. The app's built-in updater
(`resources/app-update.yml`) cannot work on NixOS, so bumping here is the only
upgrade path.
