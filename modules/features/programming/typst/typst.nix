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
  };

  # feature test: typst and typstyle are on PATH.
  # typst-live and tinymist are LSP/live-preview tools; typst --version is the
  # canonical smoke.
  flake.featureTests.typst = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("typst --version")
      machine.succeed("typstyle --version")
    '';
  };
}
