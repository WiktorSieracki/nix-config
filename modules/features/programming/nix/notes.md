# Dziennik: nix

*Ostatnia aktualizacja: 2026-07-09*

## Gotcha: `nix shell nixpkgs#pkg` dalej wymaga `--impure` dla unfree

**Objaw**: mimo że `nixpkgs.config.allowUnfree = true` jest ustawione w tej
feature'ze, `nix shell nixpkgs#obsidian` i inne komendy odwołujące się wprost
do `nixpkgs#...` (a nie do pakietów z tego flake'a) nadal odrzucają unfree.  
**Przyczyna**: `allowUnfree` na poziomie systemu dotyczy tylko pakietów
budowanych *przez ten flake* (systemPackages, home.packages). Ad hoc
`nix shell`/`nix run nixpkgs#...` ewaluuje `legacyPackages` z osobnego,
czystego (pure) wywołania flake'a nixpkgs, które nie widzi configu systemu.  
**Fix**: dodano `NIXPKGS_ALLOW_UNFREE=1` do `environment.sessionVariables`.
Legacy `nix-shell -p`/`nix-env` są impure domyślnie, więc widzą tę zmienną
od razu. Komendy flake'owe (`nix shell/run nixpkgs#...`) nadal wymagają
ręcznego `--impure`, bo flake'i są pure by default i nie czytają zmiennych
środowiskowych bez tej flagi — nie da się tego obejść deklaratywnie dla
ad hoc referencji do `nixpkgs#...` spoza tego flake'a.

**Uwaga**: próba dodania `flake.modules.homeManager.nix` (żeby zapisać
`~/.config/nixpkgs/config.nix`) zawaliła walidację hosta — `nix` jest
feature'ą `system` (współdzieloną przez `wiktor` i `work`), a HM-owa
połówka feature'y może się podłączyć tylko pod feature'y per-user.

## Gotcha: `nix` binarny jest częścią Core, nie tej feature'a

**Objaw**: asercja `nix --version` może dawać false positive — `nix`
pochodzi z Core flooru, nie z tej feature'y.  
**Przyczyna**: NixOS zawsze ma `nix` zainstalowanego jako część systemu.  
**Fix**: Próba asertuje `alejandra --version` i `nh --version`, które są
naprawdę dodawane przez tę feature'ę do `environment.systemPackages`.
