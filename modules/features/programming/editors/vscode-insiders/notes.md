# feature notes: vscode-insiders

The VS Code Insiders feature, installed as a system package (not via HM).

## Gotchas

**2026-06-26** — VS Code Insiders isn't a package in nixpkgs — it's built by overriding `pkgs.vscode.override {isInsiders = true;}` with a URL to the latest tarball.
Symptom: the `sha256-...` hash in `fetchurl` stops matching after an upstream update.
Cause: the URL `https://update.code.visualstudio.com/latest/linux-x64/insider` always points at the latest version — the hash must be updated by hand.
Fix: `nix store prefetch-file --name vscode-insiders.tar.gz https://update.code.visualstudio.com/latest/linux-x64/insider` and paste the new hash.

**2026-06-26** — The binary is named `code-insiders` (not `cursor` or `code`). The feature test asserts `command -v code-insiders` at the system level (no `su - wiktor`), because it's a system package.

**2026-06-26** — `buildInputs` needs `libxtst libjpeg8 pipewire libei` because of the bundled Copilot extension (`computer.node`). Omitting these libraries causes a link error at startup.

**2026-07-04** — A stale hash breaks not only the local rebuild but every **fresh
host install** (`nixos-install --flake github:...`): a machine without the tarball
in its store must fetch it, and `latest` already points at a newer daily → a hash
mismatch in the FOD and a cascade of "dependency failed" across the whole
system-path. The binary cache doesn't save you, because `cache-push` pushes the
runtime closure and the source tarball isn't part of it. Discovered while testing
a laptopNixos install from the release ISO in QEMU. After refreshing the hash it's
worth pushing the tarball itself to cachix too:
`cachix push wiktor-nixos $(nix store prefetch-file --json ... | jq -r .storePath)`.
