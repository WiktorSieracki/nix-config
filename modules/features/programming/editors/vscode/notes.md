# feature notes: vscode

The VS Code editor feature with an HM profile, extensions (nix4vscode) and nixd LSP config.

## Gotchas

**2026-06-26** — Extensions from `nix4vscode.forVscode [...]` are fixed-output derivations fetched from the VS Code Marketplace.
Symptom: the feature test may fail to build without internet access, or when the extensions aren't in Cachix.
Cause: `programs.vscode.profiles.default.extensions` materializes while building the nixos test.
Fix: The feature test uses `extraHmModules` with `lib.mkForce []` to zero out the extension list — we only check that the `code` binary is on PATH.

**2026-06-26** — `vscode-insiders` and `vscode` can't coexist in HM (`lib/vscode/` collision in buildEnv).
Cause: both packages share paths in `lib/vscode/`. VS Code Insiders is therefore installed as a system package, not via HM.
Fix: `vscode-insiders` uses `environment.systemPackages`, not `programs.vscode`.
