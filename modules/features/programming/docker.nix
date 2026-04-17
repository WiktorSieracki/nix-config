{
  flake.modules.nixos.docker = {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    # moved this setting to nvidia.nix
    # virtualisation.docker.enableNvidia = true;

    hardware.graphics.enable32Bit = true;
  };
}
