# git — Dziennik

Niewykonywalna wiedza o feature'rze `git`. Błędy *odtwarzalne* → asercje w
Próbie (`git.nix`), nie tutaj. Wpisy datowane, format `Objaw → Przyczyna → Fix`.

## 2026-06-26 — ukryta zależność od `sops`

**Objaw:** git „działa" na hoście, ale jego `user.email` znika / aktywacja
home-managera pada, gdy feature `sops` nie jest włączony.

**Przyczyna:** `git.nix` deklaruje `sops.secrets.studentEmail` i template z
mailem, ale **klucz** (`sops.age.sshKeyPaths`) i `defaultSopsFile` pochodzą
wyłącznie z feature'a `sops`. Bez niego nie ma czym odszyfrować.

**Fix:** `featureMeta.git.requires = ["wiktor" "sops"]` — zależność jest teraz
jawna, loader twardo failuje host z git bez sops.

## 2026-06-26 — Próba w VM bez prawdziwego klucza SOPS

**Objaw:** Próba nie może odszyfrować `secrets.yaml` — VM nie ma prywatnego
klucza ssh wiktora (recipient z `.sops.yaml`).

**Przyczyna:** realny klucz to sekret usera, świadomie nieobecny w VM.

**Fix:** stub wg ADR 0002 (b) — w Próbie `lib.mkForce` zeruje wszystkie
`sops.secrets`/`templates` (system + HM) i podmienia include maila na plaintext
przez `pkgs.writeText`. Nie testujemy deszyfracji SOPS-a (to domena sops-nix),
tylko że git/gh działają i config ląduje.
