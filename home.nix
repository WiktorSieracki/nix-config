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
    pkgs.nodejs_23
    pkgs.pnpm_9
    pkgs.nodePackages."@angular/cli"
    pkgs.tree
    pkgs.treecat

    pkgs.poetry
    pkgs.pre-commit
  ];

  imports = [
    ./modules/fish/fish.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ./modules/java.nix
    ./modules/python.nix
    ./customScripts/scriptHandler.nix
    ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
 

}
