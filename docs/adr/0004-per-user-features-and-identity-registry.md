# Feature'y per użytkownik: konta tworzy loader, tożsamość w `meta.users`

Potrzeba drugiego, odizolowanego konta (`work`) z *tym samym środowiskiem, ale
inną tożsamością* (git, profile, sekrety) obnażyła, że konkretny login był
wszyty w architekturę: loader przypinał HM wyłącznie do `wiktor`, pół grafu
miało `requires = ["wiktor"]`, a feature'y ustawiały `users.users.wiktor.*`
na sztywno. Decyzja: **host deklaruje userów, nie feature'y**.

- `features.json` zmienia format z płaskiej listy na `{ "system": [...],
  "users": { "<login>": [...] } }` (aktualizuje ADR 0003). Część NixOS
  feature'a aktywuje się, gdy feature występuje gdziekolwiek; część HM trafia
  wyłącznie do userów, którzy mają go na liście. Walidacja `requires` dla
  feature'a usera liczy się względem `system ∪ users.<login>`.
- Konto tworzy loader dla każdego klucza sekcji `users`; dane konta (pełne
  imię, grupy — w tym jawnie `wheel` — shell, referencje sekretów: email,
  hash hasła) mieszkają w rejestrze `flake.meta.users.<login>` obok
  istniejącego `flake.meta.programs`. Feature użytkownika dostaje tożsamość
  wstrzykniętą i nie zna żadnego loginu; feature'y-fundamenty `wiktor` i
  `work-user` rozpuszczają się, `requires = ["wiktor"]` znika z grafu.
- Sekrety per user (pracowy email, hash hasła worka) dostarcza **systemowy**
  sops z `owner = <login>` — HM-owy sops odpada, bo odszyfrowuje kluczem z
  home użytkownika głównego (mode 700), nieczytelnym dla innych kont. Email
  wiktora migruje na ten sam mechanizm (jedna ścieżka dostarczania).
- Próba feature'a użytkownika używa neutralnego konta `proba` — przemycony
  hardkod loginu wywala test (egzekwuje regułę konstrukcyjnie, ADR 0002).
  Izolację między kontami (home 700, brak sudo, niewidzialność pakietów per
  user) asertuje próba *mechanizmu* loadera z dwoma kontami testowymi, nie
  feature.

Odrzucone: feature-fundament per konto (`featureMeta.requires` nie wyraża
„wiktor LUB work"; to ta sama brzydota co „git z dwoma userami", tylko w
grafie); własny klucz age dla `work` (odszyfrowałby cały `secrets.yaml`, a
podział na pliki per odbiorca to dużo mechaniki za jeden email); samodzielny
rebuild z konta `work` (prawo do `nh os switch` = root = koniec izolacji —
`work` jest kontem zarządzanym). Konsekwencja do zaakceptowania: część NixOS
feature'a włączonego tylko dla jednego usera i tak działa systemowo —
niewidzialność aplikacji między kontami trzymają feature'y instalujące przez
HM (`home.packages`/`programs.*`), nie `environment.systemPackages`.
