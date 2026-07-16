# nvidia — feature notes

## 2026-06-26 — runtimeUntestable (no GPU in the VM)

**Symptom:** the driver can't be verified — the VM has no NVIDIA card.

**Cause:** the driver only loads with a physical GPU; in a VM the nvidia kernel
module simply doesn't activate (harmlessly).

**Fix:** `runtimeUntestable = true`. The feature test only checks that a system
with nvidia enabled boots to `multi-user.target` (a regression guard for driver
bumps). The closure is large (~drivers), so the feature-test build can be slow.
