{pkgs, ...}: {
  home.username = "wiktor";
  home.homeDirectory = "/home/wiktor";
  home.stateVersion = "25.11";

  # Core packages that are common across all environments
  home.packages = with pkgs; [
    alejandra
    nixd
    nix-search-cli
    nodejs_25
    pnpm
    tree
    treecat
    tealdeer

    pre-commit

    # Custom scripts
    (writeShellScriptBin "gitHttpsToSsh" (
      builtins.readFile ../customScripts/gitHttpsToSsh
    ))
    (writeShellScriptBin "pull" (builtins.readFile ../customScripts/pull))
  ];

  # Common imports for all environments
  imports = [
    ../modules/ssh.nix
    ../modules/fish/fish.nix
    ../modules/git.nix
    ../modules/nixvim.nix
    ../modules/java.nix
    ../modules/python.nix
    ../modules/magisterka/scala.nix
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
