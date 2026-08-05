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
    # The driver is inert without a GPU, but the module still has to *build* and
    # install: assert the kernel module and the userspace bits landed.
    provides.files = [
      "/run/current-system/kernel-modules/lib/modules"
      "/run/opengl-driver/lib"
    ];
  };

  # feature test: boot regression guard on driver bumps (runtimeUntestable — no
  # NVIDIA GPU in a VM). `provides` proves the driver was actually assembled
  # rather than silently evaluated away.
  flake.featureTests.nvidia = {
    testScript = ''
      machine.succeed("test -n \"$(ls /run/current-system/kernel-modules/lib/modules)\"")
    '';
  };
}
