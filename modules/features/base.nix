{
  flake.modules.nixos.nixos = {pkgs, ...}: {
    networking.networkmanager.enable = true;
    networking.hostName = "nixos"; # Define your hostname.

    services.xserver.enable = true;
    services.xserver.displayManager.gdm.enable = true;

    environment.systemPackages = with pkgs; [
      tree
      treecat
      tealdeer
      bruno-cli
      neovim
    ];
  };
}
