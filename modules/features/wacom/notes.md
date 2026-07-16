# wacom — feature notes

## 2026-06-26 — a user service, not a system one

**Symptom:** `systemctl cat opentabletdriver.service` (system scope) fails —
opentabletdriver is a **user** service (`systemd.user`).

**Fix:** the feature test checks the `otd` CLI is on PATH (the package is in
`systemPackages`) instead of a system unit. Actual tablet input is
runtimeUntestable (no tablet in the VM).
