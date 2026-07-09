# nix-config

Słownik pojęć tej konfiguracji NixOS. Nie jest to specyfikacja ani notatnik
decyzji implementacyjnych — tylko ujednolicenie języka.

## Language

**Host**:
Nazwana konfiguracja maszyny w `flake.nixosConfigurations.*`, złożona z
**feature'ów systemowych** (sekcja `system`) i **feature'ów użytkownika**
włączanych per konto (sekcja `users.<login>`). Prawdziwe maszyny
(`desktopNixos`, `laptopNixos`) zależą od swojego `hardware-configuration.nix`
i sekretów SOPS.
_Avoid_: machine, target, profile.

**Feature systemowy**:
**Feature** będący cechą maszyny (sprzęt, sieć, usługi — `nvidia`,
`ssh-server`, `tailscale`). **Host** włącza go raz, w sekcji `system`; nie
należy do żadnego konta.
_Avoid_: global feature.

**Feature użytkownika**:
**Feature** będący częścią środowiska konkretnego konta (`git`, `fish`,
`vscode`, aplikacje). **Host** włącza go per user w `users.<login>`; ten sam
feature może mieć wielu userów, ale jego treść zna tylko *jednego,
abstrakcyjnego* użytkownika — tożsamość dostaje z zewnątrz.
_Avoid_: user module, profile feature.

**Feature**:
Wielokrotnego użytku moduł w `modules/features/*`, zwykle definiujący część
NixOS i część home-manager pod tą samą nazwą. **Host** włącza **feature**'y po nazwie.
Feature jest *samowystarczalny*: jawnie deklaruje swoje zależności i nie ma
sprzężeń **funkcjonalnych** z sąsiednimi plikami (helpery .sh/.json są w jego
store-path, nie importowane spoza modułu). Layout to **folder-per-feature**
(`git/{git.nix, notes.md}`); dokumentacja obok (**Dziennik**) jest dozwolona —
nie jest zależnością funkcjonalną, bo feature działa bez niej.
_Avoid_: module (zbyt ogólne — `feature` to konkretnie ten wzorzec),
package (mylące z pakietem nixpkgs — u nas jednostką jest `feature`).

**Tożsamość** (`meta.users`):
Kanoniczny rejestr kont w `flake.meta.users.<login>`: pełne imię, grupy,
shell, adresy. Konto istnieje na **Hoście** ⇔ jego login jest kluczem sekcji
`users` tego hosta — tworzy je loader, nie feature. **Feature użytkownika**
dostaje tożsamość wstrzykniętą i nigdy nie hardkoduje loginu.
_Avoid_: user feature (dawny feature `wiktor`), account config.

**Kind** (rodzaj feature'a):
Maszynowo-czytelna kategoria w `featureMeta.<feature>.kind`, mówiąca *czym*
feature jest i jak się sprawdza, że „działa": `config` (czysta konfiguracja —
waliduje się eval + walidator np. `niri validate`), `cli` (binarka na PATH,
`--version`/smoke → exit 0), `service` (unit systemd `active` + nasłuch portu),
`gui` (proces startuje i utrzymuje okno w sesji). Steruje poziomem rygoru
**Próby**.
_Avoid_: type, category.

**Requires**:
Jawna lista zależności feature'a w `featureMeta.<feature>.requires`. Loader
**twardo failuje**, gdy host włącza feature bez kompletu `requires` na liście —
graf zależności jest zawsze pełną prawdą (dla człowieka i AI). **Próba** liczy
z tego minimalne domknięcie VM-ki.
_Avoid_: deps, imports (to ostatnie znaczy w Nix co innego).

**Core** (floor):
Nieredukowalne minimum systemu, obecne w *każdej* Próbie i każdym hoście
„ambient" (boot, nix, sieć, locale, nix-ld) — to, co zostaje po wyjęciu z
dzisiejszego worka `nixos` warstwy pulpitu. Feature **nie** wymienia `core` w
**Requires** (jest zawsze pod spodem). Minimalna VM Próby = `core` + feature +
domknięcie `requires`.
_Avoid_: base (worek `nixos` był „bazą", ale gruby i zrośnięty z niri — `core`
to świadomie odchudzona warstwa).

**Desktop** (feature):
Wydzielona z dawnej bazy warstwa sesji graficznej (`xserver`, `gdm`,
`defaultSession=niri`, GUI-pakiety). Feature o **Kind** `gui` jawnie
`requires = ["desktop" ...]`. Dzięki temu feature `cli` startuje na samym
**Core** i Próba wykrywa ukrytą zależność od pulpitu.
_Avoid_: gui-base, session.

**Próba** (test feature'a, Tier 1):
Headless `nixosTest`, który buduje **minimalną** VM = testowany feature +
domknięcie jego **Requires**, i asercją sprawdza, że feature „działa" na
poziomie rygoru z jego **Kind**. Obowiązkowa dla *każdego* feature'a (CI
failuje bez niej) — nawet trywialny feature z jednym `systemPackage` musi
udowodnić, że binarka się odpala. Pada, gdy feature ma niezadeklarowaną
zależność → wymusza modularność konstrukcyjnie. **Feature'y użytkownika**
testuje na neutralnym koncie testowym (`proba`), nie na realnym loginie —
hardkod czyjegoś loginu w feature'rze wywala jego Próbę.
_Avoid_: smoke-test, unit test, sprawdzenie.

**Próba hosta** (e2e, Tier 2):
Headless test bootujący cały **Host** (lub kuratorowaną grupę feature'ów) i
sprawdzający asercje *między* feature'ami (np. „user w grupie docker I
`docker run` przechodzi"). To jest „end-to-end" — integracja, nie izolacja.
Rzadszy, cieńsza warstwa nad **Próbami** feature'ów.
_Avoid_: integration test, test integracyjny.

**Dziennik** (feature'a, `notes.md`):
Datowany zapis **niewykonywalnej** wiedzy o feature'rze: dziwactwa upstreamu,
„czemu ten workaround", pułapki środowiska. Czytany przez `/nix-loop` na starcie
(by nie wyprowadzać znanych problemów od zera) i auto-dopisywany z datą, gdy
pętla rozwiąże coś nowego. Granica względem **Próby**: błąd *odtwarzalny* idzie
jako asercja w Próbie (nie zgnije), Dziennik trzyma tylko to, czego nie da się
sensownie zakodować w teście. Struktura wpisu: `Objaw → Przyczyna → Fix`.
_Avoid_: README, docs, notes.

**runtimeUntestable** (flaga w `featureMeta`):
Furtka (c) z ADR 0002: oznacza feature, którego *runtime* nie da się zweryfikować
w VM (brak sprzętu — `nvidia`/`wacom`/`mouse`; brak realnej sieci/klucza SOPS —
`eduroam`/`home-wifi`/`sops`). Taki feature **wciąż ma Próbę**, ale sprawdza ona
tylko, że moduł integruje się i system bootuje (regresja eval/boot), nie samo
działanie sprzętu/sekretu.
_Avoid_: untestable, skip.

**Work user**:
Drugie zwykłe konto uniksowe (`work`) na tym samym **Hoście** co użytkownik
główny — separacja *danych i tożsamości* (profile, konta, sekrety, historia),
nie separacja wykonywalności (bez MAC). Bez sudo, homeMode 700. Konto
**zarządzane**: jego **feature'y użytkownika** przełącza i aktywuje użytkownik
główny — prawo przebudowy systemu równałoby się rootowi i unieważniło izolację.
_Avoid_: osobny host, work-VM, konto służbowe jako maszyna.

**Switchboard**:
TUI (feature `switchboard`, binarka `switchboard`) do zarządzania listami
**feature**'ów prawdziwych **host**'ów — osobno sekcją `system` i każdą
`users.<login>` (w tym **work userem**, w rękach użytkownika głównego):
checkboxy z wyszukiwarką, jawne domykanie **Requires** przy zaznaczaniu,
feature-diff jako potwierdzenie, finał przez `nh os test`/`switch`; globalnie
także bump `flake.lock`. Edytuje pliki danych hostów — nie dotyka `.nix`.
_Avoid_: features-cli, manager, panel.

**ISO** (obraz live):
Jeden **generyczny** obraz live (host `iso`), bootowalny na dowolnej maszynie.
Nie jest „obrazem laptopa" ani „obrazem desktopa" — to środowisko
live/instalacyjne. Wyboru docelowego **host**'a dokonuje się dopiero przy
instalacji z ISO (`nixos-install --flake .#desktopNixos | .#laptopNixos`).
Świadomie pomija **feature**'y sprzętowe (`nvidia/wacom/mouse`) i zależne od
sekretów (`sops/git/eduroam/...`), bo nie aktywują się bez klucza maszyny.
_Avoid_: image obrazu maszyny, installer per-host.

**Release** (rolling `latest`):
Pojedynczy, nadpisywany wydanie GitHub pod tagiem `latest`, niosące najnowsze
**ISO** + `checksums.txt`. Stabilny URL pobierania zamiast historii datowanej.
_Avoid_: snapshot, versioned release.

### Flagged ambiguities

- **„image"** bywa mylone z „obrazem konkretnej maszyny". W tym repo wydajemy
  **jeden generyczny ISO**; per-maszynowe obrazy odrzucono, bo po odfiltrowaniu
  sprzętu i sekretów `iso-desktop` i `iso-laptop` byłyby niemal identyczne.

### Przykładowy dialog

> — Wypuśćmy nowy **release**.
> — OK, push do `main` zbuduje **ISO** z hosta `iso` i nadpisze tag `latest`.
> — A jak z tego zainstaluję laptopa?
> — Bootujesz to samo **ISO** i robisz `nixos-install --flake .#laptopNixos` —
>   wybór **host**'a jest na etapie instalacji, nie pobierania.
>
> — Chcę slacka na koncie work.
> — `slack` to **feature użytkownika** — Switchboardem dopisujesz go do
>   `users.work` desktopa i aktywujesz jako wiktor; **work user** jest kontem
>   zarządzanym.
> — A skąd git worka wie, jakim mailem commitować?
> — Z **Tożsamości**: `meta.users.work` wskazuje sekret z pracowym mailem, a
>   feature `git` dostaje ją wstrzykniętą — sam nie zna żadnego loginu, co
>   pilnuje jego **Próba** na koncie `proba`.
