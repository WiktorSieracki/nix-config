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

## 2026-07-06 — email przeniesiony na system-level sops per user (ADR 0004)

**Objaw (przed zmianą):** HM-owy sops odszyfrowuje kluczem z home
użytkownika głównego (`age.sshKeyPaths` w `sops.nix` HM wskazywał na
`/home/wiktor/.ssh/id_ed25519`) — dla każdego innego konta (np. `work`) to
po prostu nieczytelny plik.

**Przyczyna:** HM ewaluuje się per user, ale sops-nix zawsze bierze klucz
z filesystemu tego konkretnego home, więc HM-owy sops nie skaluje się na
wiele kont bez własnego klucza age per user (odrzucone — p. ADR 0004).

**Fix:** `homeManager.sops` (część HM) usunięty całkowicie. `git.nix`
renderuje teraz jeden systemowy sops template `git-email-<login>` na konto,
które ma `git` na liście i wpis `emailSecret` w `flake.meta.users` — feature
sam wylicza to z `hostUsers` (wstrzykniętego przez loader) i
`config.flake.meta.users`, `owner` szablonu to ten login. HM-owa część git
tylko odczytuje ścieżkę już wyrenderowanego pliku przez `osConfig`.
