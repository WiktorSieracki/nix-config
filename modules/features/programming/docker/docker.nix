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

  # Rootless Docker daemon (user-level systemd service). No user dep because
  # `virtualisation.docker.rootless` does not scope itself to a named user at
  # the NixOS level — any user who opts in runs their own daemon instance.
  flake.featureMeta.docker = {
    requires = [];
    kind = "service";
  };

  # feature test: docker CLI is on PATH (rootless installs it system-wide). The daemon
  # itself is a systemd *user* service and cannot be asserted with
  # machine.wait_for_unit() in nixosTest (no user session started). We stub out
  # hardware.graphics.enable32Bit to avoid pulling in 32-bit Mesa — it has no
  # effect on CLI or daemon reachability in headless CI.
  flake.featureTests.docker = {
    extraNixosModules = [
      ({lib, ...}: {
        hardware.graphics.enable32Bit = lib.mkForce false;
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("docker --version")
    '';
  };
}
