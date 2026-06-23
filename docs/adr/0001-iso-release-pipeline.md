# Wydawanie jednego generycznego ISO przez GitHub Actions + Cachix

Wypuszczamy **jeden generyczny obraz live** (host `iso`) jako rolling release
GitHub pod tagiem `latest`, budowany na każdy push do `main` (z pominięciem
zmian czysto-dokumentacyjnych) oraz ręcznie. Build idzie na `ubuntu-latest`,
dysk zwalnia `wimpysworld/nothing-but-nix`, a `nix-fast-build` pcha closure do
własnego publicznego cache'a Cachix `wiktor-nixos`.

## Considered Options

- **Obrazy per-host (`iso-desktop`, `iso-laptop`)** — odrzucone. Po odfiltrowaniu
  modułów sprzętowych (`nvidia/wacom/mouse`) i zależnych od sekretów
  (`sops/eduroam/...`), które jako jedyne odróżniają te maszyny, oba obrazy
  byłyby niemal identyczne (różnica: `chromium`). Podwójny koszt CI za zero zysku.
- **Release datowane bez prune (model MrSom3body)** — odrzucone przy buildzie na
  push do main: rosłyby lawinowo (release/commit). Rolling `latest` daje stabilny
  URL i zero bałaganu.
- **Bez Cachix (sam cache.nixos.org)** — closure ISO jest niemal w całości
  prebuilt, więc Cachix nie jest konieczny do *zbudowania*. Wybrano go mimo to,
  by inni mogli `nix build` hosta `iso` bez przebudowy i by przyspieszyć
  inkrementalne buildy przy częstych pushach.

## Consequences

- Wybór maszyny (desktop/laptop) następuje przy instalacji z ISO
  (`nixos-install --flake .#desktopNixos | .#laptopNixos`), nie przy pobieraniu.
- Wymaga publicznego cache'a Cachix `wiktor-nixos` i sekretu repo
  `CACHIX_AUTH_TOKEN`; repo musi być publiczne dla pobierania release'u.
- ISO świadomie nie zawiera sekretów ani sterowników sprzętowych — patrz
  [CONTEXT.md](../../CONTEXT.md) (pojęcie **ISO**).
