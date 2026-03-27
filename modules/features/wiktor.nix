{self, ...}: {
  flake.modules = {
    nixos.wiktor = {pkgs, ...}: {
      home-manager = {
        backupFileExtension = ".bak";
        useGlobalPkgs = true;
        useUserPackages = true;
      };

      users.users.wiktor = {
        isNormalUser = true;
        description = "wiktor";
        extraGroups = ["networkmanager" "wheel"];
      };
    };

    homeManager.wiktor = {pkgs, ...}: {
      home.username = "wiktor";
      home.homeDirectory = "/home/wiktor";
      home.stateVersion = "24.11";

      programs.home-manager.enable = true;
    };
  };
}
