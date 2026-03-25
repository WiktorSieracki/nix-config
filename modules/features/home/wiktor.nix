{self, ...}: {
  flake.homeModules.wiktor = {
    imports = [self.homeModules.firefox];
    home.username = "wiktor";
    home.homeDirectory = "/home/wiktor";
    home.stateVersion = "24.11";
  };
}
 