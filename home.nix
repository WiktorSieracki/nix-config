{ config, pkgs, ... }:

{
  home.username = "wiktor";
  home.homeDirectory = "/home/wiktor";

  home.stateVersion = "24.05";

  # environment.
  home.packages = [
    pkgs.neovim
    pkgs.git
    pkgs.pnpm_8
    pkgs.nodePackages."@angular/cli"
  ];

  imports = [
    ./modules/fish.nix
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
 

}
