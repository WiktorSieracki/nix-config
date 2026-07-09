# sops — Dziennik

## 2026-06-26 — runtimeUntestable: brak klucza w VM

**Objaw:** Próba nie może zweryfikować deszyfracji — VM nie ma prywatnego klucza
ssh wiktora (recipient z `.sops.yaml`).

**Przyczyna:** deszyfracja to istota feature'a, a klucz jest świadomie nieobecny
w VM (sekret usera). Deszyfrowanie to domena sops-nix, nie nasza.

**Fix:** `featureMeta.sops.runtimeUntestable = true`. Próba zeruje sekrety
(`lib.mkForce`) i sprawdza tylko, że moduł integruje się, system bootuje, a CLI
`sops` jest na PATH. Realna deszyfracja weryfikowana wyłącznie na żywej maszynie.

## 2026-07-06 — usunięta część HM (ADR 0004)

**Objaw:** brak — usunięcie prewencyjne, nie naprawa.

**Przyczyna:** `homeManager.sops` odszyfrowywał zawsze kluczem
`/home/wiktor/.ssh/id_ed25519` niezależnie od tego, które konto ewaluuje HM —
działał tylko dla wiktora. Jedyny konsument (`git`'s email) przeszedł na
system-level sops z `owner` per konto (p. `git/notes.md`), więc HM-owa
połowa nie miała już żadnego użycia.

**Fix:** `homeManager.sops` skasowany. Sops zostaje wyłącznie system-level;
sekrety dla nie-roota trafiają do kont przez `owner`/render systemowego
sops-nix (jak już robił `cachixAuthToken`), nigdy przez HM.
