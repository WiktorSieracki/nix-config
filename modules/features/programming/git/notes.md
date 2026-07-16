# git — feature notes

Non-executable knowledge about the `git` feature. *Reproducible* bugs → assertions
in the feature test (`git.nix`), not here. Dated entries, format
`Symptom → Cause → Fix`.

## 2026-06-26 — hidden dependency on `sops`

**Symptom:** git "works" on the host, but its `user.email` disappears / home-manager
activation fails when the `sops` feature isn't enabled.

**Cause:** `git.nix` declares `sops.secrets.studentEmail` and an email template, but
the **key** (`sops.age.sshKeyPaths`) and `defaultSopsFile` come only from the `sops`
feature. Without it there's nothing to decrypt with.

**Fix:** `featureMeta.git.requires = ["wiktor" "sops"]` — the dependency is now
explicit, and the loader hard-fails a host with git but without sops.

## 2026-06-26 — feature test in a VM without a real SOPS key

**Symptom:** the feature test can't decrypt `secrets.yaml` — the VM has no wiktor
private ssh key (the recipient from `.sops.yaml`).

**Cause:** the real key is a user secret, deliberately absent from the VM.

**Fix:** a stub per ADR 0002 (b) — in the feature test, `lib.mkForce` zeroes all
`sops.secrets`/`templates` (system + HM) and swaps the email include for plaintext
via `pkgs.writeText`. We don't test SOPS decryption (that's sops-nix's domain),
only that git/gh work and the config lands.

## 2026-07-06 — email moved to system-level sops per user (ADR 0004)

**Symptom (before the change):** HM sops decrypts with a key from the main user's
home (`age.sshKeyPaths` in HM's `sops.nix` pointed at
`/home/wiktor/.ssh/id_ed25519`) — for any other account (e.g. `work`) that's just an
unreadable file.

**Cause:** HM evaluates per user, but sops-nix always takes the key from that
specific home's filesystem, so HM sops doesn't scale to multiple accounts without a
per-user age key (rejected — see ADR 0004).

**Fix:** `homeManager.sops` (the HM part) removed entirely. `git.nix` now renders one
system sops template `git-email-<login>` per account that has `git` on its list and
an `emailSecret` entry in `flake.meta.users` — the feature computes this itself from
`hostUsers` (injected by the loader) and `config.flake.meta.users`, and the
template's `owner` is that login. The HM part of git only reads the path of the
already-rendered file via `osConfig`.
