{
  flake.modules.nixos.docker = {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    virtualisation.docker.enableNvidia = true;

    hardware.graphics.enable32Bit = true;
  };
}
