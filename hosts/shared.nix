{
  config,
  pkgs,
  flakeRoot,
  ...
}:

{
  home.username = "wiktor";
  home.homeDirectory = "/home/wiktor";
  home.stateVersion = "24.05";

  # Core packages that are common across all environments
  home.packages = with pkgs; [
    # pkgs.nixfmt
    pkgs.nixfmt-rfc-style
    pkgs.nix-search-cli
    pkgs.nodejs_24
    pkgs.pnpm_9
    pkgs.nodePackages."@angular/cli"
    pkgs.tree
    pkgs.treecat

    pkgs.pre-commit
  ];

  # Common imports for all environments
  imports = [
    (flakeRoot + /modules/fish/fish.nix)
    (flakeRoot + /modules/git.nix)
    (flakeRoot + /modules/nvim.nix)
    (flakeRoot + /modules/java.nix)
    (flakeRoot + /modules/python.nix)
    (flakeRoot + /modules/typst.nix)
    (flakeRoot + /customScripts/scriptHandler.nix)
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
