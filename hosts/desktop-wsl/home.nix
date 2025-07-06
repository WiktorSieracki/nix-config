{ config, pkgs, ... }:

{
  imports = [
    ../shared.nix
  ];

  # WSL-specific packages
  home.packages = with pkgs; [

  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # WSL-specific PATH additions or other env vars
    DISPLAY = ":0"; # For X11 forwarding if needed
  };

  # WSL-specific configuration
  targets.genericLinux.enable = true;
}
