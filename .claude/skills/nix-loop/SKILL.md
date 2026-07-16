---
name: nix-loop
description: Drive a feature's feature test (nixosTest) to green — build it, read the failure, fix the feature or its test, repeat. The feedback engine reused by /install-feature and /update-feature. Use when a feature's feature test is red, or to verify a feature works in a VM.
---

# /nix-loop

Headless feedback loop for a single feature `<f>`. Runs **only in VMs** — never
`nh os switch`/`test` on the real machine.

## Procedure

1. **Read the feature notes first.** Open `modules/.../<f>/notes.md` (if it exists) so
   you don't re-derive problems already solved. See [[project_proba_harness]].
2. **Build the feature test:** `nix build .#checks.x86_64-linux.feature-<f> -L`
3. **Green (exit 0)?** Done — report the passing assertions.
4. **Red?** Diagnose, then fix and rebuild:
   - *Eval/build error* (Nix): usually a missing `requires`, an undeclared option,
     or a secret-backed activation. Fix `featureMeta.<f>.requires`, or stub SOPS
     in the feature test (`lib.mkForce` blank `sops.secrets/templates/age.sshKeyPaths`,
     inject plaintext — see `modules/features/programming/git/git.nix`).
   - *testScript assertion failed*: the feature genuinely doesn't do what the test
     asserts, or the assertion is wrong. Fix whichever is actually wrong.
   - Edit the feature file and/or its `featureTests.<f>.testScript` autonomously
     (it's a VM, safe). Do NOT touch the real system.
5. **Stop conditions:** max ~5 iterations; stop early if the same error repeats
   twice (the loop is stuck). On exhaustion, report the last `testScript` output +
   your diagnosis — do not claim success.
6. **GUI feature tests** may be flaky — retry once before declaring failure.
7. **On resolving a NEW non-reproducible gotcha**, append a dated entry to
   `modules/.../<f>/notes.md` (`## YYYY-MM-DD — title`, then `Objaw → Przyczyna →
   Fix`, Polish). Reproducible bugs become testScript assertions instead.

## Notes
- Check naming: `feature-<name>` (Tier-1) / `host-<name>` (Tier-2 e2e).
- `feature-coverage` (`nix build .#checks.x86_64-linux.feature-coverage`) asserts
  every feature with `featureMeta` also has a feature test and vice-versa.
- Background `nh os switch --dry` notifications can lag behind your edits; trust
  your own `nix eval`/`nix build`, not stale notifications.
