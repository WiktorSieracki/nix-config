# Dziennik: vscode-insiders

Feature VS Code Insiders instalowanego jako system package (nie przez HM).

## Gotchas

**2026-06-26** — VS Code Insiders nie jest paczką w nixpkgs — budowany jest przez nadpisanie `pkgs.vscode.override {isInsiders = true;}` z URL do najnowszego tarballa.
Objaw: hash `sha256-...` w `fetchurl` przestaje pasować po aktualizacji upstream.
Przyczyna: URL `https://update.code.visualstudio.com/latest/linux-x64/insider` wskazuje zawsze na najnowszą wersję — hash musi być aktualizowany ręcznie.
Fix: `nix store prefetch-file --name vscode-insiders.tar.gz https://update.code.visualstudio.com/latest/linux-x64/insider` i wklejenie nowego hasha.

**2026-06-26** — Binarka nosi nazwę `code-insiders` (nie `cursor` ani `code`). Próba asertuje `command -v code-insiders` na poziomie systemu (bez `su - wiktor`), bo to system package.

**2026-06-26** — `buildInputs` wymaga `libxtst libjpeg8 pipewire libei` z powodu bundled Copilot extension (`computer.node`). Pominięcie tych bibliotek skutkuje błędem linkowania przy starcie.

**2026-07-04** — Nieaktualny hash psuje nie tylko lokalny rebuild, ale każdą
**świeżą instalację hosta** (`nixos-install --flake github:...`): maszyna bez
tarballa w store musi go pobrać, a `latest` już wskazuje nowszy daily → hash
mismatch w FOD i kaskada "dependency failed" na całym system-path. Binary
cache nie ratuje, bo `cache-push` pushuje closure runtime, a źródłowy tarball
do niego nie należy. Wykryte przy teście instalacji laptopNixos z release'owego
ISO w QEMU. Po odświeżeniu hasha warto wypchnąć do cachix też sam tarball:
`cachix push wiktor-nixos $(nix store prefetch-file --json ... | jq -r .storePath)`.
