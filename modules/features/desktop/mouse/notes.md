# mouse (G502) — Dziennik

## 2026-06-26 — serwis g502 blokuje boot w VM

**Objaw:** `g502-apply-buttons.service` (oneshot, `wantedBy=multi-user.target`)
odpytuje 30×2s o fizyczną mysz — w VM blokuje `multi-user.target` na ~60s.

**Fix:** Próba wyłącza ten serwis (`lib.mkForce false` w `extraNixosModules`).
Testuje to, co realne i niezależne od sprzętu: skrypty `mic-mute-toggle`,
`deafen-toggle`, `g502-apply-buttons` na PATH oraz jednostkę `ratbagd.service`.
Sam remap przycisków jest runtimeUntestable (brak myszy w VM).
