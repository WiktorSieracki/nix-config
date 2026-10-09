# latex — feature notes

## 2026-10-09 — why `texliveFull`

The feature exists to compile locally the projects that live on Overleaf (via the
VS Code *Overleaf Workshop* extension, which can mirror a project into a local
folder). Overleaf's compile servers ship a full TeX Live, so anything smaller
here means a document that builds on overleaf.com and fails locally with a
missing `.sty`. `texliveFull` costs roughly 7 GB of `/nix/store` and is enabled
on `desktopNixos` only — the laptop deliberately omits it.

Use the *top-level* scheme attrs (`texliveFull`, `texliveMedium`, …). The older
`texlive.combined.scheme-*` set still evaluates but prints a deprecation warning
and is scheduled for removal in nixpkgs 27.05.

If the laptop ever needs it, prefer `texliveMedium` there rather than a
hand-picked `texlive.withPackages` set: the small schemes are missing fonts and
language support that Overleaf templates assume.

## 2026-10-09 — the editor half lives in `vscode`

`latex` is a pure system feature (`kind = "cli"`): the toolchain on PATH. The
VS Code extensions (`James-Yu.latex-workshop`, `iamhyc.overleaf-workshop`) and
their settings sit in `modules/features/programming/editors/vscode/vscode.nix`,
mirroring how `typst` keeps the compiler while `tinymist` is listed in
`vscode.nix`. Consequence: enabling `latex` without `vscode` is valid and gives
a working CLI toolchain — `requires` stays empty, so the feature test boots
without a desktop.

`latex-workshop.latex.outDir` is set to `%DIR%/build` so `.aux`/`.fdb_latexmk`
droppings don't land next to the sources and get synced back up to Overleaf.

## 2026-10-09 — the feature test compiles, not just `command -v`

`provides.systemBins` already proves the binaries resolve. A texlive closure can
still fail to *compile* (missing format files, unwritable `TEXMFVAR`), so the
test script builds a minimal document with `latexmk -pdf` and asserts a non-empty
PDF. Keep it that way; a PATH-only assertion here is near-worthless.

## 2026-10-09 — the extensions are only guarded by host eval

`feature-vscode` sets `nixpkgs.overlays = lib.mkForce []`, so nix4vscode is
absent in that VM and the extension list falls back to `[]`. A broken or removed
marketplace ID therefore does *not* fail `nix flake check` — it fails the host
eval (`nix eval .#nixosConfigurations.desktopNixos...toplevel.drvPath`) or the
switch. Verified by hand on 2026-10-09: `James-Yu.latex-workshop` 10.19.0 and
`iamhyc.overleaf-workshop` 0.15.10 both fetch and build.
