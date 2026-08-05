{
  flake.modules.nixos.affine = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      affine
    ];
  };

  flake.featureMeta.affine = {
    requires = ["desktop"];
    kind = "gui";
    provides.systemBins = ["affine"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.affine = {};
}
