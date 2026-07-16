# feature notes: brave

The Brave browser feature with extensions configured via HM (`programs.brave.extensions`).

## Gotchas

**2026-06-26** — `programs.brave.extensions` takes lists of Chrome Web Store extension IDs (not nix packages).
These extensions are fetched by the browser itself on first launch, not by nix — the feature test doesn't need to stub them.
The binary installed by HM is named `brave` (mainProgram from nixpkgs).
