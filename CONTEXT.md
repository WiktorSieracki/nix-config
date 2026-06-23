# nix-config

Słownik pojęć tej konfiguracji NixOS. Nie jest to specyfikacja ani notatnik
decyzji implementacyjnych — tylko ujednolicenie języka.

## Language

**Host**:
Nazwana konfiguracja maszyny w `flake.nixosConfigurations.*`, złożona z listy
**feature**'ów. Prawdziwe maszyny (`desktopNixos`, `laptopNixos`) zależą od
swojego `hardware-configuration.nix` i sekretów SOPS.
_Avoid_: machine, target, profile.

**Feature**:
Wielokrotnego użytku moduł w `modules/features/*`, zwykle definiujący część
NixOS i część home-manager pod tą samą nazwą. **Host** włącza **feature**'y po nazwie.
_Avoid_: module (zbyt ogólne — `feature` to konkretnie ten wzorzec).

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
