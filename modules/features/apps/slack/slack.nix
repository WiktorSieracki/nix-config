{
  # Installed via home-manager (`home.packages`), NOT environment.systemPackages,
  # so it lands only in the listing account's PATH/launcher (per-user profile) —
  # the app-invisibility boundary between accounts (ADR 0004).
  flake.modules.homeManager.slack = {pkgs, ...}: {
    home.packages = [pkgs.slack];
  };

  flake.featureMeta.slack = {
    requires = ["desktop"];
    kind = "gui";
    provides.userBins = ["slack"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.slack = {};
}
