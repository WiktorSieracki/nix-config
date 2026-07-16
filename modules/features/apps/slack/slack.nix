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
  };

  flake.featureTests.slack = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v slack'")
    '';
  };
}
