{
  flake.modules.nixos.nvidia = {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.open = true;
    hardware.nvidia.powerManagement.enable = true;
  };
}
