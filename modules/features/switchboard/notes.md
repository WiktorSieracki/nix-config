# switchboard — Dziennik

Niewykonywalna wiedza o feature'rze `switchboard`. Błędy *odtwarzalne* →
asercje w Próbie (`switchboard.nix`), nie tutaj. Wpisy datowane, format
`Objaw → Przyczyna → Fix`.

## 2026-07-03 — Próba z `nix` w domknięciu `requires` a read-only `nixpkgs.config`

**Objaw:** pierwsza Próba padła na evalu: „The option
`nodes.machine.nixpkgs.config` is defined multiple times … nixpkgs.config is
set to read-only". Switchboard to pierwszy feature, którego `requires`
dociąga `nix` do VM-ki Próby.

**Przyczyna:** feature `nix` ustawia `nixpkgs.config.allowUnfree = true`, a
`nixosTest` dostaje gotowe `pkgs` i oznacza `nixpkgs.config` node'a jako
read-only — każda dodatkowa definicja to konflikt.

**Fix:** ten sam stub, którego używa własna Próba feature'a `nix`:
`extraNixosModules = [ ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};}) ]`.
Dotyczy KAŻDEJ przyszłej Próby, której domknięcie `requires` zawiera `nix`.

## 2026-07-03 — `app.suspend()` „połyka" output komendy po jej zakończeniu

**Objaw:** po `nh os test` odpalonym spod TUI output (w tym nvd-diff) znika
w ułamku sekundy — nie da się go przeczytać.

**Przyczyna:** Textual rysuje w alternate screen terminala; wyjście z
kontekstu `App.suspend()` natychmiast wraca do alternate screen i zasłania
wszystko, co komenda wypisała.

**Fix:** po `subprocess.call(...)` a przed końcem `suspend()` blokujące
`input("… press Enter to return")` — użytkownik czyta output i sam wraca do
TUI. `EOFError` trzeba złapać (brak stdin ≠ crash).

## 2026-07-03 — SelectionList (Textual 8.x): stan trzymać w modelu, nie w widżecie

**Objaw:** przy filtrze na żywo + auto-dociąganiu zależności checkboxy
„gubią" stan; programowe `select()/deselect()` odpala kolejne
`SelectionToggled` i łatwo o pętlę zdarzeń.

**Przyczyna:** filtr wymaga przebudowy listy opcji (widoczny jest podzbiór),
więc widżet nie może być źródłem prawdy; API select/deselect różni się między
wersjami Textuala i emituje zdarzenia jak toggle użytkownika.

**Fix:** źródłem prawdy jest lista `enabled` w ekranie; każda zmiana →
`clear_options()` + `add_option(...)` z `initial_state` z modelu, pod flagą
`_rebuilding` ignorującą zdarzenia w trakcie. Blokada odznaczenia = odmowa w
modelu + rebuild (checkbox wraca sam).
