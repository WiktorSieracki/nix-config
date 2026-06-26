# Feature jako jednostka samowystarczalna, weryfikowalna headless (AI-first)

Każdy **Feature** staje się jednostką *samowystarczalną i samoopisującą się*: w
jednym pliku `.nix` kontrybuuje moduł NixOS/HM, **`featureMeta`** (`requires` +
`kind`) oraz obowiązkową **Próbę** — headless `nixosTest`, który buduje minimalną
VM (`core` + feature + domknięcie `requires`) i asercją sprawdza, że feature
„działa" na poziomie rygoru z jego `kind`. Loader **twardo failuje**, gdy host
włącza feature bez kompletu `requires` na liście, a eval-time `feature-coverage`
failuje, gdy istnieje moduł bez `featureMeta` lub bez Próby. Cel: modularność
*egzekwowana konstrukcyjnie* i pętla feedbacku sterowalna przez AI.

## Decyzje składowe

- **`featureMeta.<f> = { requires; kind; }`** — jawny, maszynowo-czytelny graf
  zależności. `kind ∈ {config, cli, service, gui}` steruje poziomem rygoru Próby
  (config/cli/service → L2, gui → L1 na start). Flaga `runtimeUntestable`
  zwalnia z asercji runtime feature'y nieuchwytne bez realnej infry (np.
  `eduroam`).
- **Próba na `nixosTest`, nie na interaktywnym runnerze `build.vm`** — headless,
  deterministyczna, zwraca kod wyjścia; pasuje do pętli AI. Runner `build.vm`
  zostaje do oglądania okiem przez człowieka.
- **Dwa poziomy** — **Próba feature'a** (Tier 1, izolacja: min VM = `core` +
  feature + `requires`) i **Próba hosta** (Tier 2, e2e: asercje *między*
  feature'ami na hoście).
- **Folder-per-feature**: `<f>/{<f>.nix, notes.md}`. Plik `.nix` =
  moduł + meta + Próba, składane helperem `flake.proba.mkProba` (osobny attr,
  bo `flake.lib` jest niezadeklarowane i flake-parts nie scala go między
  modułami). Checki nazwane
  `feature-<nazwa>` / `host-<nazwa>`. Reguła „samowystarczalności" zakazuje
  sprzężeń *funkcjonalnych* między plikami, nie dokumentacji obok.
- **Dziennik (`notes.md`)** — datowany zapis *niewykonywalnej* wiedzy
  (dziwactwa upstreamu, workaroundy). `/nix-loop` czyta go na starcie i
  auto-dopisuje z datą po rozwiązaniu problemu. Granica: błąd *odtwarzalny* →
  asercja w Próbie (nie zgnije); Dziennik → tylko to, czego nie da się zakodować.
- **Rozcięcie bazy na `core` + feature `desktop`** — dawny worek
  `flake.modules.nixos.nixos` hardkodował sesję niri (`xserver`, `gdm`,
  `defaultSession=niri`, GUI-pakiety), przez co litmus test *„czy feature działa
  bez niri?"* był niewykonalny. `core` = nieredukowalne minimum (ambient,
  nie w `requires`); `desktop` = jawnie wymagany przez feature'y `gui`.
- **SOPS w Próbie** — domyślnie **stub** sekretu (ścieżka → plaintext fixture),
  z `runtimeUntestable` jako furtką dla nieuchwytnych przypadków.
- **CI local-first** — eval-time `feature-coverage` + tanie Próby (`cli`/`config`)
  w CI (gate na regresje, niezależny/lekki dla KVM), ciężkie Próby (`gui`/
  `service`) lokalnie (KVM na desktopie); green-buildy do Cachix `wiktor-nixos`.

## Considered Options (odrzucone)

- **Zależności niejawne / asercje Nix-native** — AI nie może *z góry* policzyć
  domknięcia VM (uczy się dopiero przez błąd eval). `featureMeta` to jedno
  źródło prawdy dla walidacji, składania VM i wszystkich skilli.
- **Gruba baza jako floor Prób** — najprościej, ale litmus test pozostaje fikcją
  (każda VM wstaje z pełnym pulpitem). Odrzucone na rzecz `core`+`desktop`.
- **Pełny `nix flake check` (wszystkie Próby) w CI na każdy PR** — zakłada
  niezawodny KVM na runnerze; ryzyko wolnego/kruchego CI. Odłożone.

## Consequences

- Jednorazowy refaktor: rozcięcie bazy, dodanie `featureMeta`+Próby do *każdego*
  z ~40 feature'ów (rekomendowany rollout: harness + pilot na jednym feature'rze,
  potem migracja reszty), walidacja w `loadNixosAndHmModuleForUser`.
- Skille operują na tym modelu: `/search-nix`, `/install-feature`,
  `/update-feature`, `/nix-loop`, `/remove-feature`. `/nix-loop` kręci się
  wyłącznie w VM (≤5 iteracji, stop na powtórce błędu, autonomiczne edycje
  pliku feature'a); `nh os test/switch` na metalu zawsze poza pętlą i jawnie.
- „Package" wycofane z języka projektu na rzecz **Feature** — patrz
  [CONTEXT.md](../../CONTEXT.md).
