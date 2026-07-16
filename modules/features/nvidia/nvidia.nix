{
  flake.modules.nixos.nvidia = {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia.open = true;
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.powerManagement.enable = true;
  };

  # No NVIDIA GPU in a VM — the driver is inert, so runtime is untestable. The
  # feature test proves the config integrates and the system still boots cleanly with
  # the nvidia driver/kernel-module set up (regression guard on driver bumps).
  flake.featureMeta.nvidia = {
    requires = [];
    kind = "config";
    runtimeUntestable = true;
  };

  flake.featureTests.nvidia = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
    '';
  };
}
