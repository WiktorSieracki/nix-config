{
  # Installed via home-manager (`home.packages`), NOT environment.systemPackages,
  # so it lands only in the listing account's PATH/launcher (per-user profile) —
  # the app-invisibility boundary between accounts (ADR 0004).
  flake.modules.homeManager.slack = {pkgs, ...}: {
    home.packages = [pkgs.slack];
  };

  flake.featureMeta.slack = {
    requires = [];
    kind = "gui";
  };

  flake.probaTests.slack = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v slack'")
    '';
  };
}
