{
  flake.modules.nixos."hosts/desktopNixos" = {pkgs, ...}: {
    networking.networkmanager.enable = true;
    networking.hostName = "nixos"; # Define your hostname.

    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;
  };
}
