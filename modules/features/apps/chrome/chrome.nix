{
  # Google Chrome (not `brave`, the meta chromium-browser) — deliberate for the
  # work account's Google workspace. Installed via home-manager so it stays out
  # of other accounts' PATH/launcher (ADR 0004).
  flake.modules.homeManager.chrome = {pkgs, ...}: {
    home.packages = [pkgs.google-chrome];
  };

  flake.featureMeta.chrome = {
    requires = [];
    kind = "gui";
  };

  flake.probaTests.chrome = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v google-chrome-stable'")
    '';
  };
}
