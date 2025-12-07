{
  config,
  pkgs,
  ...
}: {
  home.username = "wiktor";
  home.homeDirectory = "/home/wiktor";
  home.stateVersion = "25.11";

  # Core packages that are common across all environments
  home.packages = with pkgs; [
    pkgs.alejandra
    pkgs.nix-search-cli
    pkgs.nodejs_25
    pkgs.pnpm
    pkgs.tree
    pkgs.treecat
    pkgs.tealdeer

    pkgs.pre-commit

    # Custom scripts
    (pkgs.writeShellScriptBin "gitHttpsToSsh" (
      builtins.readFile (../customScripts/gitHttpsToSsh)
    ))
    (pkgs.writeShellScriptBin "pull" (builtins.readFile (../customScripts/pull)))
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
