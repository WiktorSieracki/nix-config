# Dziennik: fish

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: fish-ssh-agent plugin z fetchFromGitHub wymaga sieciowego fetcha

**Objaw**: build w piaskownicy bez sieci (sandbox = true) może failować przy
fetchFromGitHub dla pluginu `fish-ssh-agent`.  
**Przyczyna**: Nix sandbox nie ma dostępu do internetu — hash musi być w
locker lub fetched wcześniej.  
**Fix**: SHA256 jest zahardkodowany (`cFroQ7...`), więc Nix może zweryfikować
i pobrać go z binary cache. Jeśli plugin zmieni rev, trzeba zaktualizować sha256.

## Gotcha: `users.users.wiktor.shell` wymaga, żeby user wiktor istniał

> **[2026-07-06]** Wpis nieaktualny po ADR 0004: feature `wiktor` został
> rozpuszczony, `requires` na login zniknęło z całego grafu. Zobacz wpis
> „Shell przeniesiony do `meta.users`" niżej.

**Objaw**: moduł NixOS fish ustawia `users.users.wiktor.shell = pkgs.fish`,
co zakłada, że user wiktor jest już zdefiniowany.  
**Przyczyna**: moduł `wiktor` tworzy usera; fish go modyfikuje — bez `wiktor`
w `requires` host mógłby nie mieć usera.  
**Fix**: `featureMeta.fish.requires = ["wiktor"]` — loader twardo failuje
przy próbie włączenia fish bez wiktor.

## 2026-07-06 — Shell przeniesiony do `meta.users` (ADR 0004)

**Kontekst:** feature'y użytkownika (git, fish, vscode, …) mogą teraz trafiać
na listę wielu kont (np. `work`), więc żaden feature nie może hardkodować
loginu. `fish.nix` już nie ustawia `users.users.<kogokolwiek>.shell` — to
robi loader (`mkHostUser`) na podstawie `flake.meta.users.<login>.shell`.

**Konsekwencja dla Próby:** shell fisha weryfikuje osobny check mechanizmu
(`checks.host-users`, `modules/proba.nix`), nie Próba `fish` — jej zadaniem
jest tylko udowodnić, że pakiet `fish` i HM-owy direnv istnieją na koncie
testowym `proba`, niezależnie od tego, czy `proba` ma fisha jako login shell.
