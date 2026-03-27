{
  flake.modules.nixos.nixos = {pkgs, ...}: {
    networking.networkmanager.enable = true;
    hardware.bluetooth.enable = true;
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;

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
