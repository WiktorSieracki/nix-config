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

> **[2026-07-04]** Wpis dotyczy wycofanej implementacji Python/Textual.
> Ten sam problem (i analogiczny fix) występuje w wersji Go — patrz wpis
> „`tea.ExecProcess` wraca do alternate screen…" niżej.

**Objaw:** po `nh os test` odpalonym spod TUI output (w tym nvd-diff) znika
w ułamku sekundy — nie da się go przeczytać.

**Przyczyna:** Textual rysuje w alternate screen terminala; wyjście z
kontekstu `App.suspend()` natychmiast wraca do alternate screen i zasłania
wszystko, co komenda wypisała.

**Fix:** po `subprocess.call(...)` a przed końcem `suspend()` blokujące
`input("… press Enter to return")` — użytkownik czyta output i sam wraca do
TUI. `EOFError` trzeba złapać (brak stdin ≠ crash).

## 2026-07-03 — SelectionList (Textual 8.x): stan trzymać w modelu, nie w widżecie

> **[2026-07-04]** Wpis dotyczy wycofanej implementacji Python/Textual.
> Zasada „stan w modelu, nie w widżecie" przeszła do wersji Go naturalnie:
> bubbletea (Elm architecture) nie ma stanowych widżetów — źródłem prawdy
> jest lista `enabled` w modelu, checkboxy renderują się z niej przy każdym
> View().

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

## 2026-07-04 — Rewrite na Go + bubbletea (wersja Python/Textual wycofana)

Logika domenowa przeszła 1:1 (domknięcie `requires`, blokada odznaczenia,
reconciliacja kolejności zapisu, diff flake.lock) — teraz w czystych funkcjach
(`model.go`, `lock.go`, `grid.go`) pod unit testami `go test ./...`.
Implementacja Python zostaje w historii gita (ostatnio commit `9c3b3e4`) jako
referencja.

## 2026-07-04 — `buildGoModule` ze `src = ./.` w folderze feature'a

**Objaw:** brak — ale dwie nieoczywiste konsekwencje trzymania źródeł Go
bezpośrednio w folderze feature'a.

**Przyczyna/wiedza:** (1) `src = ./.` obejmuje też `switchboard.nix` i
`notes.md`, więc *każdy* wpis do Dziennika przebudowuje pakiet — akceptowalne
(build trwa sekundy), ale nie dziwić się rebuildom. (2) `buildGoModule`
odpala w checkPhase `go test ./...` — unit testy muszą być hermetyczne (bez
sieci/gita), za to każdy build systemu jest bramkowany testami za darmo.

**Fix (workflow vendorHash):** wpisać `lib.fakeHash` (albo dowolny
`sha256-AAAA…=`), zbudować pakiet przez
`nix build --impure --expr 'let flake = builtins.getFlake (toString /ścieżka/repo); pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux; in pkgs.buildGoModule { … }'`
i przepisać hash z komunikatu `got: sha256-…`. Uwaga: nowe pliki `.go` muszą
być `git add`nięte *przed* tym buildem (flake widzi tylko śledzone pliki).

## 2026-07-04 — `tea.ExecProcess` wraca do alternate screen i zasłania output

**Objaw:** ten sam co w Textualu: po `nh os test`/`nix build --dry-run`
odpalonym spod TUI output znika natychmiast po zakończeniu komendy —
bubbletea wraca do alternate screen.

**Przyczyna:** `tea.ExecProcess` oddaje terminal procesowi, ale po jego
wyjściu program od razu re-renderuje TUI w alternate screen.

**Fix:** komendę opakować w `sh -c` ze skryptem: `cmd; rc=$?; printf '…press
Enter…'; read -r _ || true; exit $rc`. `read` dostaje stdin = realny TTY (bo
to wciąż ExecProcess), `|| true` chroni przed EOF (brak stdin ≠ crash), a
`exit $rc` propaguje kod wyjścia komendy do callbacka (`*exec.ExitError`).

## 2026-07-04 — `go vet`/`go test` poza Nixem: brak `gcc` na PATH

**Objaw:** `nix shell nixpkgs#go -c go test ./...` pada na
`cgo: C compiler "gcc" not found` (buduje `runtime/cgo`).

**Przyczyna:** goły `nixpkgs#go` nie ciągnie toolchainu C, a cgo jest
domyślnie włączone.

**Fix:** `CGO_ENABLED=0` — projekt jest pure-Go. W `buildGoModule` problem
nie występuje (stdenv ma cc).

## 2026-07-06 — migracja na `{system, users}` (ADR 0004)

**Kontekst:** `features.json` przestał być płaską listą — teraz
`{"system": [...], "users": {"<login>": [...]}}`. `HostSpec` (model.go)
zastępuje gołe `[]string`; `Sections()`/`Get`/`Set`/`Clone`/`SpecEqual`
operują na całym spec-u, a UI dostał zakładki sekcji (`tab`/`[`/`]`) — każda
edytowana niezależnie, `enable()` liczy domknięcie `requires` względem
`system ∪ bieżąca sekcja` (metoda `satisfiers()`), nie całego pliku.

**Pułapka do zapamiętania:** `enable()` sprawdza już-obecne zależności przez
`contains(m.enabled(), dep)` — bez tego auto-dociąganie potrafiłoby dodać
duplikat feature'a, który jest spełniony przez `system`, ale nie przez samą
sekcję usera. Test jednostkowy tego nie łapie (za mało scenariuszy w
`model_test.go`) — jeśli coś tu się popsuje, objawi się jako duplikat w
`features.json` po zapisaniu, nie jako crash.

## 2026-07-04 — `--help` z exit 0 bez TTY: `flag.ExitOnError`

Próba wymaga `switchboard --help` z kodem 0 w headless VM. Pakiet `flag` z
`flag.ExitOnError` robi to out-of-the-box: `-h`/`--help` → usage + `os.Exit(0)`
(inne błędy parsowania → exit 2). Nie zmieniać na ContinueOnError bez
przeniesienia tej semantyki.
