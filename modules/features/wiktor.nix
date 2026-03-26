{self, ...}: {
  flake.modules.homeManager.wiktor = {pkgs, ...}: {
    home.username = "wiktor";
    home.homeDirectory = "/home/wiktor";
    home.stateVersion = "24.11";
  };
}
