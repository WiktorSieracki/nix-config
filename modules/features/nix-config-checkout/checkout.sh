#!/usr/bin/env bash
# Clone this repository into the account's own checkout, if it isn't there yet.
#
# `NH_FLAKE`/`FLAKE` (set by the `nix` feature) point every account at
# ~/.config/nix-config, so on a machine where that directory does not exist
# `nh os switch` fails before it starts. This puts it there.
#
# Never fails the caller. It runs from a systemd user unit, and a unit that can
# fail on a flaky network is a unit that leaves the session degraded — exactly
# the failure mode that took `home-manager-<user>.service` down when a network-
# independent activation step was allowed to exit non-zero.
set -uo pipefail

target="$HOME/.config/nix-config"

if [ -e "$target" ]; then
  echo "nix-config-checkout: $target already exists, leaving it alone"
  exit 0
fi

mkdir -p "$(dirname "$target")"

if ! git clone --quiet "@httpsUrl@" "$target"; then
  # No network, DNS not up yet, GitHub down — all the same to us. Clean up the
  # half-made directory so the next run starts from a known state.
  echo "nix-config-checkout: clone failed (offline?), will try again next login" >&2
  rm -rf "$target"
  exit 0
fi

# Fetch over HTTPS (works with no key), push over SSH (uses the account's key).
git -C "$target" remote set-url --push origin "@sshUrl@"

echo "nix-config-checkout: cloned into $target"
