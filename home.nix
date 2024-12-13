{ config, pkgs, ... }:

let
  username = builtins.getEnv "USER";
in
{
  home.username = "${username}";
  home.homeDirectory = "/home/${username}";

  home.stateVersion = "24.05";

  # environment.
  home.packages = [
    pkgs.pnpm_8
    pkgs.nodePackages."@angular/cli"
  ];

  imports = [
    ./modules/fish.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
 

}
