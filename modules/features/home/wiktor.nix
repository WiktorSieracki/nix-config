{self, ...}: {
  flake.homeModules.wiktor = {pkgs, ...}: {
    imports = [
      self.homeModules.firefox
      self.homeModules.git
      self.homeModules.ssh
    ];

    home.username = "wiktor";
    home.homeDirectory = "/home/wiktor";
    home.stateVersion = "24.11";
  };
}
