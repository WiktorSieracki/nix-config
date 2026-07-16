# feature notes: cursor-ide

The Cursor IDE editor feature, installed via HM as `pkgs.code-cursor`.

## Gotchas

**2026-06-26** — The binary is named `cursor` (mainProgram of nixpkgs `code-cursor`), not `cursor-ide` or `code-cursor`.
The feature test asserts `command -v cursor` via `su - wiktor`.
