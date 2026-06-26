{...}: {
  flake.modules.homeManager.cursor-ide = {pkgs, ...}: {
    home.packages = [pkgs.code-cursor];
  };

  flake.featureMeta.cursor-ide = {
    requires = ["wiktor"];
    kind = "gui";
  };

  flake.probaTests.cursor-ide = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'command -v cursor'")
    '';
  };
}
