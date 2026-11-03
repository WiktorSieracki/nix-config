# feature notes: fish

*Last updated: 2026-06-26*

## Gotcha: the fish-ssh-agent plugin from fetchFromGitHub needs a network fetch

**Symptom**: a sandboxed build without network (sandbox = true) may fail on
fetchFromGitHub for the `fish-ssh-agent` plugin.
**Cause**: the Nix sandbox has no internet access — the hash must be in the lock or
fetched beforehand.
**Fix**: the SHA256 is hardcoded (`cFroQ7...`), so Nix can verify it and pull it
from a binary cache. If the plugin changes rev, the sha256 must be updated.

## Gotcha: `users.users.wiktor.shell` requires that the wiktor user exists

> **[2026-07-06]** Entry outdated after ADR 0004: the `wiktor` feature was
> dissolved, and `requires` on a login disappeared from the whole graph. See the
> "Shell moved to `meta.users`" entry below.

**Symptom**: the NixOS fish module sets `users.users.wiktor.shell = pkgs.fish`,
which assumes the wiktor user is already defined.
**Cause**: the `wiktor` module creates the user; fish modifies it — without
`wiktor` in `requires` a host might not have the user.
**Fix**: `featureMeta.fish.requires = ["wiktor"]` — the loader hard-fails on an
attempt to enable fish without wiktor.

## 2026-07-06 — Shell moved to `meta.users` (ADR 0004)

**Context:** user features (git, fish, vscode, …) can now land on the list of
multiple accounts (e.g. `work`), so no feature may hardcode a login. `fish.nix` no
longer sets `users.users.<anyone>.shell` — the loader (`mkHostUser`) does, based on
`flake.meta.users.<login>.shell`.

**Consequence for the feature test:** the fish login shell is verified by a
separate mechanism check (`checks.host-users`, `modules/feature-tests.nix`), not by
the `fish` feature test — its only job is to prove the `fish` package and the HM
direnv exist on the test account `tester`, regardless of whether `tester` has fish
as a login shell.

## 2026-11-03 — Own command-not-found handler (`command-not-found.sh`)

**Why:** nix-index only looks up a binary by its exact name, so `hetzner` got a
bare "command not found" even with `hcloud` installed, and its hints use
`nix-env -iA`, which does not fit a flake-managed machine.

**Costs, measured on desktopNixos:** `nix search` takes 1.6 s and 50 MB with the
eval cache warm, 22 s and 4.5 GB without it. The cache key is the pinned nixpkgs,
so every nixpkgs bump makes the next miss cold. Hence the 3 s budget and the
background warm-up, which is skipped under 6 GiB of available memory (the VPS
case): there the hint tells you to run `nix search` by hand.

**Limit:** `nix search` matches substrings, so a typo like `ripgrp` finds nothing.
