# Releasing one generic ISO via GitHub Actions + Cachix

We ship **one generic live image** (host `iso`) as a rolling GitHub release under
the tag `latest`, built on every push to `main` (docs-only changes excluded) and
manually. The build runs on `ubuntu-latest`, `wimpysworld/nothing-but-nix` frees
disk space, and `nix-fast-build` pushes the closure to our own public Cachix cache
`wiktor-nixos`.

## Considered Options

- **Per-host images (`iso-desktop`, `iso-laptop`)** — rejected. After filtering
  out the hardware modules (`nvidia/wacom/mouse`) and secret-dependent ones
  (`sops/eduroam/...`), which are the only things distinguishing these machines,
  both images would be nearly identical (difference: `chromium`). Double the CI
  cost for zero gain.
- **Dated releases without prune (MrSom3body model)** — rejected for a build on
  every push to main: they would grow explosively (one release per commit). A
  rolling `latest` gives a stable URL and zero clutter.
- **No Cachix (just cache.nixos.org)** — the ISO closure is almost entirely
  prebuilt, so Cachix isn't strictly required to *build* it. Chosen anyway so
  others can `nix build` the `iso` host without a rebuild, and to speed up
  incremental builds on frequent pushes.

## Consequences

- The machine choice (desktop/laptop) happens at install time from the ISO
  (`nixos-install --flake .#desktopNixos | .#laptopNixos`), not at download time.
- Requires the public Cachix cache `wiktor-nixos` and the repo secret
  `CACHIX_AUTH_TOKEN`; the repo must be public for release downloads.
- The ISO deliberately carries no secrets or hardware drivers — see
  [CONTEXT.md](../../CONTEXT.md) (the **ISO** term).

## Update 2026-07-04: splitting the image into parts

GitHub rejects release files ≥ 2 GiB, and the image (a full desktop live: niri,
firefox, libreoffice, …) is ~4.2 GB after squashfs compression. Slimming it under
the limit would require cutting most applications (the system closure is
~12.8 GB), which would contradict the idea of a desktop live ISO — instead the
release contains the image `split` into 1990 MB parts (`nixos.iso.part-*`),
reassembled with `cat` per the instructions in the release body. `checksums.txt`
verifies both the parts and the reassembled image.
