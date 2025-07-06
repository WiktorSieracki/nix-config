{ config, pkgs, ... }:

{
  imports = [
    ../shared.nix
    ../../modules/vscode.nix
  ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # NixOS laptop-specific packages
  home.packages = with pkgs; [

  ];

  # NixOS-specific settings
  home.sessionVariables = {
    # NixOS-specific environment variables
    NIX_PATH = "nixpkgs=${pkgs.path}";
  };

  # NixOS-specific configuration
  # This runs on a full NixOS system, so we can assume more integration
  programs.fish.interactiveShellInit = ''
    # Enable Vi mode
    fish_vi_key_bindings
  '';
}
