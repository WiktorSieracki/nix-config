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

**Objaw**: moduł NixOS fish ustawia `users.users.wiktor.shell = pkgs.fish`,
co zakłada, że user wiktor jest już zdefiniowany.  
**Przyczyna**: moduł `wiktor` tworzy usera; fish go modyfikuje — bez `wiktor`
w `requires` host mógłby nie mieć usera.  
**Fix**: `featureMeta.fish.requires = ["wiktor"]` — loader twardo failuje
przy próbie włączenia fish bez wiktor.
