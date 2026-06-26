# Dziennik: vscode-insiders

Feature VS Code Insiders instalowanego jako system package (nie przez HM).

## Gotchas

**2026-06-26** — VS Code Insiders nie jest paczką w nixpkgs — budowany jest przez nadpisanie `pkgs.vscode.override {isInsiders = true;}` z URL do najnowszego tarballa.
Objaw: hash `sha256-...` w `fetchurl` przestaje pasować po aktualizacji upstream.
Przyczyna: URL `https://update.code.visualstudio.com/latest/linux-x64/insider` wskazuje zawsze na najnowszą wersję — hash musi być aktualizowany ręcznie.
Fix: `nix store prefetch-file --name vscode-insiders.tar.gz https://update.code.visualstudio.com/latest/linux-x64/insider` i wklejenie nowego hasha.

**2026-06-26** — Binarka nosi nazwę `code-insiders` (nie `cursor` ani `code`). Próba asertuje `command -v code-insiders` na poziomie systemu (bez `su - wiktor`), bo to system package.

**2026-06-26** — `buildInputs` wymaga `libxtst libjpeg8 pipewire libei` z powodu bundled Copilot extension (`computer.node`). Pominięcie tych bibliotek skutkuje błędem linkowania przy starcie.
