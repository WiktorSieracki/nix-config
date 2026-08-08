{...}: {
  flake.modules.homeManager.cursor-ide = {pkgs, ...}: {
    home.packages = [pkgs.code-cursor];
  };

  flake.featureMeta.cursor-ide = {
    requires = ["desktop"];
    kind = "gui";
    provides.userBins = ["cursor"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.cursor-ide = {};
}
