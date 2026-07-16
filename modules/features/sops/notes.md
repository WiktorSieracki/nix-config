# sops — feature notes

## 2026-06-26 — runtimeUntestable: no key in the VM

**Symptom:** the feature test can't verify decryption — the VM has no wiktor private
ssh key (the recipient from `.sops.yaml`).

**Cause:** decryption is the essence of the feature, and the key is deliberately
absent from the VM (a user secret). Decrypting is sops-nix's domain, not ours.

**Fix:** `featureMeta.sops.runtimeUntestable = true`. The feature test zeroes the
secrets (`lib.mkForce`) and only checks that the module integrates, the system
boots, and the `sops` CLI is on PATH. Real decryption is verified only on a live
machine.

## 2026-07-06 — HM part removed (ADR 0004)

**Symptom:** none — a preventive removal, not a fix.

**Cause:** `homeManager.sops` always decrypted with the key
`/home/wiktor/.ssh/id_ed25519` regardless of which account evaluates HM — it only
worked for wiktor. Its only consumer (`git`'s email) moved to system-level sops with
per-account `owner` (see `git/notes.md`), so the HM half had no use left.

**Fix:** `homeManager.sops` deleted. Sops stays system-level only; secrets for
non-root land on accounts via `owner`/system sops-nix rendering (as
`cachixAuthToken` already did), never via HM.
