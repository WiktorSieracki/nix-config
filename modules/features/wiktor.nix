{self, ...}: {
  flake.modules = {
    nixos.wiktor = {pkgs, ...}: {
      home-manager.backupFileExtension = ".bak";
    };

    homeManager.wiktor = {pkgs, ...}: {
      home.username = "wiktor";
      home.homeDirectory = "/home/wiktor";
      home.stateVersion = "24.11";

      programs.home-manager.enable = true;
    };
  };
}
