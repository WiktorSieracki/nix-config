# wacom — Dziennik

## 2026-06-26 — serwis użytkownika, nie systemowy

**Objaw:** `systemctl cat opentabletdriver.service` (skala systemu) zawodzi —
opentabletdriver to serwis **użytkownika** (`systemd.user`).

**Fix:** Próba sprawdza obecność CLI `otd` na PATH (pakiet jest w
`systemPackages`) zamiast jednostki systemowej. Realne wejście z tabletu jest
runtimeUntestable (brak tabletu w VM).
