{
  # Google Chrome (not `brave`, the meta chromium-browser) — deliberate for the
  # work account's Google workspace. Installed via home-manager so it stays out
  # of other accounts' PATH/launcher (ADR 0004).
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
