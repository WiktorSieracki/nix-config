# nvidia — Dziennik

## 2026-06-26 — runtimeUntestable (brak GPU w VM)

**Objaw:** nie da się zweryfikować sterownika — VM nie ma karty NVIDIA.

**Przyczyna:** sterownik ładuje się tylko przy fizycznym GPU; w VM moduł jądra
nvidia po prostu się nie aktywuje (nieszkodliwie).

**Fix:** `runtimeUntestable = true`. Próba sprawdza tylko, że system z włączonym
nvidia bootuje do `multi-user.target` (regression guard na bumpy sterownika).
Domknięcie jest duże (~sterowniki), więc build Próby bywa wolny.
