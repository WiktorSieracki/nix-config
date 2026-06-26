# sops — Dziennik

## 2026-06-26 — runtimeUntestable: brak klucza w VM

**Objaw:** Próba nie może zweryfikować deszyfracji — VM nie ma prywatnego klucza
ssh wiktora (recipient z `.sops.yaml`).

**Przyczyna:** deszyfracja to istota feature'a, a klucz jest świadomie nieobecny
w VM (sekret usera). Deszyfrowanie to domena sops-nix, nie nasza.

**Fix:** `featureMeta.sops.runtimeUntestable = true`. Próba zeruje sekrety
(`lib.mkForce`) i sprawdza tylko, że moduł integruje się, system bootuje, a CLI
`sops` jest na PATH. Realna deszyfracja weryfikowana wyłącznie na żywej maszynie.
