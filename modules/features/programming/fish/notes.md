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
