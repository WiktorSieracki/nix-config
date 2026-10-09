{
  flake.modules.nixos.latex = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      # texliveFull mirrors what Overleaf's compile servers ship, so a project
      # mirrored from Overleaf compiles locally without hunting for .sty files.
      # It is the big one (~7 GB closure) — that is the deliberate trade.
      # (Top-level scheme, not `texlive.combined.scheme-full`: the latter is
      # deprecated in nixpkgs and goes away in 27.05.)
      texliveFull
    ];
  };

  # Pure system feature: the TeX toolchain on PATH. The VS Code side (LaTeX
  # Workshop + Overleaf Workshop extensions and their settings) lives in the
  # `vscode` feature, the same split typst/tinymist already uses.
  flake.featureMeta.latex = {
    requires = [];
    kind = "cli";
    # latexmk is the build driver LaTeX Workshop invokes; biber and latexindent
    # back bibliographies and format-on-save.
    provides.systemBins = ["pdflatex" "xelatex" "lualatex" "latexmk" "biber" "latexindent"];
  };

  # feature test: `provides` covers PATH, so the script proves the toolchain
  # actually produces a PDF — a texlive closure can be complete and still fail
  # to compile (missing format files, unwritable TEXMFVAR).
  flake.featureTests.latex = {
    testScript = ''
      machine.succeed("mkdir -p /tmp/tex")
      machine.succeed(
          "cat > /tmp/tex/doc.tex <<'TEX'\n"
          "\\documentclass{article}\n"
          "\\usepackage[T1]{fontenc}\n"
          "\\usepackage{amsmath}\n"
          "\\begin{document}\n"
          "Hello \\(e^{i\\pi} = -1\\).\n"
          "\\end{document}\n"
          "TEX"
      )
      machine.succeed("cd /tmp/tex && latexmk -pdf -interaction=nonstopmode doc.tex")
      machine.succeed("test -s /tmp/tex/doc.pdf")
    '';
  };
}
