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

  flake.featureTests.chrome = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v google-chrome-stable'")
    '';
  };
}
