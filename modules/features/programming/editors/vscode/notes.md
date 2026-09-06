# feature notes: vscode

The VS Code editor feature with an HM profile, extensions (nix4vscode) and nixd LSP config.

## Gotchas

**2026-06-26** — Extensions from `nix4vscode.forVscode [...]` are fixed-output derivations fetched from the VS Code Marketplace.
Symptom: the feature test may fail to build without internet access, or when the extensions aren't in Cachix.
Cause: `programs.vscode.profiles.default.extensions` materializes while building the nixos test.
Fix: The feature test uses `extraHmModules` with `lib.mkForce []` to zero out the extension list — we only check that the `code` binary is on PATH.

**2026-08-17** — The `NoctaliaTheme` colour theme never applies on a fresh home (VM / reinstall): VS Code loads the extension's shipped placeholder navy `#070722` instead of the active scheme.
Cause: noctalia doesn't ship a static theme — its `code` template *rewrites* `themes/NoctaliaTheme-color-theme.json` inside the installed extension. It finds that extension by scanning `~/.vscode/extensions` for dirs whose name starts with `noctalia.noctaliatheme-` (trailing dash, `Scripts/python/src/theming/vscode-helper.py`). HM installs the extension as `noctalia.noctaliatheme` (no version) and as a *symlink into the store*, so noctalia neither matches the name nor could write to it. On the author's desktop it only worked because of a hand-installed marketplace copy at `noctalia.noctaliatheme-0.0.5/` — undeclared state the config never reproduced (and a duplicate extension identifier alongside the HM one).
Fix: the extension is excluded from the HM extension list and installed by `home.activation.noctaliaVscodeTheme` as a writable `noctalia.noctaliatheme-<version>/` copy. The colour JSON is preserved across activations — never clobber what noctalia rendered.
