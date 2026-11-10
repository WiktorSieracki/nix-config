{
  # Google Chrome (not `brave`, the meta chromium-browser) — for a Google
  # Workspace that wants the real thing. Installed via home-manager, so it is
  # on the accounts' PATH/launcher rather than the system profile.
  flake.modules.homeManager.chrome = {pkgs, ...}: {
    home.packages = [pkgs.google-chrome];
  };

  flake.featureMeta.chrome = {
    requires = ["desktop"];
    kind = "gui";
    provides.userBins = ["google-chrome-stable"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.chrome = {};
}
