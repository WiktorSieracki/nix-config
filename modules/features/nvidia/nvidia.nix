{
  flake.modules.nixos.nvidia = {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = ["nvidia"];
    hardware.nvidia.open = true;
    hardware.nvidia.modesetting.enable = true;
    hardware.nvidia.powerManagement.enable = true;

    # GPU passthrough into containers. This is the setting docker.nix refers to
    # as "moved to nvidia.nix" — it generates CDI specs under /var/run/cdi, which
    # rootless Docker reads (it has no privileged runtime hook). Consume it from
    # compose with `driver: cdi` + `device_ids: [nvidia.com/gpu=all]`.
    hardware.nvidia-container-toolkit.enable = true;
  };

  # No NVIDIA GPU in a VM — the driver is inert, so runtime is untestable. The
  # feature test proves the config integrates and the system still boots cleanly with
  # the nvidia driver/kernel-module set up (regression guard on driver bumps).
  flake.featureMeta.nvidia = {
    requires = [];
    kind = "config";
    runtimeUntestable = true;
  };

  # The test VM has no NVIDIA driver, so nvidia-container-toolkit's driver
  # assertion fires there even though it holds on the real host. Suppress it in
  # CI only — same stubbing pattern docker.nix uses for enable32Bit.
  flake.featureTests.nvidia = {
    extraNixosModules = [
      ({lib, ...}: {
        hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = lib.mkForce true;
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
    '';
  };
}
