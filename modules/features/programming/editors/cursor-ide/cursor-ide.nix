{...}: {
  flake.modules.homeManager.cursor-ide = {pkgs, ...}: {
    home.packages = [pkgs.code-cursor];
  };

  flake.featureMeta.cursor-ide = {
    requires = [];
    kind = "gui";
  };

  flake.probaTests.cursor-ide = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-proba.service")
      machine.succeed("su - proba -c 'command -v cursor'")
    '';
  };
}
