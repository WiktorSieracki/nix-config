{
  flake.modules.homeManager.blender = {pkgs, ...}: {
    home.packages = [pkgs.blender];
  };

  flake.featureMeta.blender = {
    requires = ["desktop"];
    kind = "gui";
    provides.userBins = ["blender"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.blender = {};
}
