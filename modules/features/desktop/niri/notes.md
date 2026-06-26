# Dziennik: niri

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: Próba nie uruchamia kompozytora (brak GPU w VM)

**Objaw**: headless `nixosTest` nie może wyświetlić sesji Wayland — VM
startuje bez GPU, `niri` uruchomiony jako program crashuje.  
**Przyczyna**: niri wymaga działającego Wayland EGL / GPU.  
**Fix**: Próba sprawdza tylko, że binarny `niri` jest na PATH (pakiet
zainstalowany przez `programs.niri.enable`). Pełne smoke-testy kompozytora
wymagają `virtio-vga-gl` i są robione manualnie przez człowieka (`vm` host).

## Gotcha: myNiri zależy od niriBinds i myNoctalia

**Objaw**: eval niri feature'a wymaga, żeby `flake.niriBinds` i
`self'.packages.myNoctalia` były zdefiniowane.  
**Przyczyna**: perSystem w niri.nix buduje `myNiri` przez wrapper-modules,
który scala wszystkie `flake.niriBinds` i embeduje ścieżkę do myNoctalia.  
**Fix**: featureMeta.niri ma `requires = []` — oba atrybuty są dostępne
przez flake-parts merge (niriBinds z wielu plików, myNoctalia z noctalia.nix)
i nie wymagają jawnego `requires`.
