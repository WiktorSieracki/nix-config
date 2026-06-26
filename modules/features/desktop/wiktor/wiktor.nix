{
  flake.modules = {
    nixos.wiktor = {
      home-manager = {
        backupFileExtension = ".bak";
        useGlobalPkgs = true;
        useUserPackages = true;
      };

      users.users.wiktor = {
        isNormalUser = true;
        description = "wiktor";
        extraGroups = [
          "networkmanager"
          "wheel"
        ];
      };

      security.sudo.wheelNeedsPassword = false;
    };

    homeManager.wiktor = {
      home.username = "wiktor";
      home.homeDirectory = "/home/wiktor";
      home.stateVersion = "24.11";

      programs.home-manager.enable = true;
    };
  };

  # Foundation feature: creates the `wiktor` normal user with home-manager
  # wiring (backupFileExtension, useGlobalPkgs, useUserPackages). All features
  # that configure wiktor's home environment list this in `requires`.
  flake.featureMeta.wiktor = {
    requires = [];
    kind = "config";
  };

  # Próba: prove the user exists and can be looked up.
  flake.probaTests.wiktor = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("getent passwd wiktor")
      machine.succeed("id wiktor | grep -q wiktor")
    '';
  };
}
