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
    # pkgs.nixfmt
    pkgs.nixfmt-rfc-style
    pkgs.nix-search-cli
    pkgs.nodejs_23
    pkgs.pnpm_9
    pkgs.nodePackages."@angular/cli"
    pkgs.tree
    pkgs.treecat

    pkgs.poetry
    pkgs.pre-commit
    pkgs.jq
    pkgs.go
    pkgs.uv
  ];

  imports = [
    ./modules/fish/fish.nix
    ./modules/git.nix
    ./modules/nvim.nix
    ./modules/java.nix
    ./modules/python.nix
    ./modules/typst.nix
    ./customScripts/scriptHandler.nix
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

}
