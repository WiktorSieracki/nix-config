# syncthing — notes

## Keys and device IDs (2026-11-03)

Each machine's key lives in `~/.local/state/syncthing`, is never in this repo,
and determines the device ID hardcoded in `syncthing.nix`. A reinstalled machine
gets a new ID unless that directory is restored. To add or replace a machine:

```bash
nix shell nixpkgs#syncthing -c syncthing generate --home="$HOME/.local/state/syncthing"
nix shell nixpkgs#syncthing -c syncthing device-id --home="$HOME/.local/state/syncthing"
```

Then add the ID to `devices` and deploy to every peer.

## First sync of a new folder

`syncthing-init` adds the folder first and posts `ignorePatterns` after it, so a
scan can start with no ignores in place. Write the same patterns to `.stignore`
in the folder on both sides before the first activation, or `.git` may start
syncing during that window.

## Checking it

The GUI is on `127.0.0.1:8384`; on the VPS, reach it with `ssh -L 8384:localhost:8384 vps`.
Deleted and overwritten files are kept in `.stversions/` in the folder, per machine.
