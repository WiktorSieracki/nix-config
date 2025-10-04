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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
    pkgs.tealdeer

    pkgs.pre-commit

    # Custom scripts
    (pkgs.writeShellScriptBin "gitHttpsToSsh" (
      builtins.readFile (flakeRoot + /customScripts/gitHttpsToSsh)
    ))
    (pkgs.writeShellScriptBin "pull" (builtins.readFile (flakeRoot + /customScripts/pull)))
    (pkgs.writeShellScriptBin "manage" (builtins.readFile (flakeRoot + /customScripts/manage)))
  ];

  # Common imports for all environments
  imports = [
    (flakeRoot + /modules/ssh.nix)
    (flakeRoot + /modules/fish/fish.nix)
    (flakeRoot + /modules/git.nix)
    (flakeRoot + /modules/nixvim.nix)
    (flakeRoot + /modules/java.nix)
    (flakeRoot + /modules/python.nix)
    (flakeRoot + /modules/typst.nix)
    (flakeRoot + /modules/magisterka/scala.nix)
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
