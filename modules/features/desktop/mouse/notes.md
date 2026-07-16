# mouse (G502) — feature notes

## 2026-06-26 — the g502 service blocks boot in a VM

**Symptom:** `g502-apply-buttons.service` (oneshot, `wantedBy=multi-user.target`)
polls for the physical mouse 30×2s — in a VM it blocks `multi-user.target` for ~60s.

**Fix:** the feature test disables that service (`lib.mkForce false` in
`extraNixosModules`). It tests what's real and hardware-independent: the
`mic-mute-toggle`, `deafen-toggle`, `g502-apply-buttons` scripts on PATH and the
`ratbagd.service` unit. The button remap itself is runtimeUntestable (no mouse in
the VM).
