{...}: {
  flake.modules.homeManager.cursor-ide = {pkgs, ...}: {
    home.packages = [pkgs.code-cursor];
  };
}
