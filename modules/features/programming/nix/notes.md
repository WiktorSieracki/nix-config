# Dziennik: nix

*Ostatnia aktualizacja: 2026-06-26*

## Gotcha: `nix` binarny jest częścią Core, nie tej feature'a

**Objaw**: asercja `nix --version` może dawać false positive — `nix`
pochodzi z Core flooru, nie z tej feature'y.  
**Przyczyna**: NixOS zawsze ma `nix` zainstalowanego jako część systemu.  
**Fix**: Próba asertuje `alejandra --version` i `nh --version`, które są
naprawdę dodawane przez tę feature'ę do `environment.systemPackages`.
