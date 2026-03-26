{
  flake.modules.nixos.nvidia = {pkgs, ...}: {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia.open = true;
    hardware.nvidia.powerManagement.enable = true;
  };
}
