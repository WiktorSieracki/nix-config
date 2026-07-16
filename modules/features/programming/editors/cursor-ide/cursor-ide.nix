{...}: {
  flake.modules.homeManager.cursor-ide = {pkgs, ...}: {
    home.packages = [pkgs.code-cursor];
  };

  flake.featureMeta.cursor-ide = {
    requires = [];
    kind = "gui";
  };

  flake.featureTests.cursor-ide = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v cursor'")
    '';
  };
}
