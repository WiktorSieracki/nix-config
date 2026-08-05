{
  flake.modules.nixos.typst = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      typst
      typstyle
      typst-live
      font-awesome
      tinymist
    ];
  };

  # Pure system feature: typst compiler and associated tools on PATH.
  flake.featureMeta.typst = {
    requires = [];
    kind = "cli";
    # typst-live and tinymist are LSP/live-preview tools; these two are the
    # canonical smoke.
    provides.systemBins = ["typst" "typstyle"];
  };

  # feature test: `provides` covers PATH; the version calls are the runtime smoke.
  flake.featureTests.typst = {
    testScript = ''
      machine.succeed("typst --version")
      machine.succeed("typstyle --version")
    '';
  };
}
