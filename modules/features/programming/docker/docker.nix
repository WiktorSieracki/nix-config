{
  flake.modules.nixos.docker = {lib, ...}: {
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };
    # moved this setting to nvidia.nix
    # virtualisation.docker.enableNvidia = true;

    # The daemon is a user unit wanted by default.target in *every* user's
    # systemd instance, and nixpkgs only excludes root. System accounts get
    # an instance too — the SDDM greeter runs one — and have no subuid range
    # for rootlesskit to map, so each greeter login tried the daemon, failed,
    # and retried until the start limit (measured: 12 failed starts as `sddm`
    # in two weeks). `@system` covers root as well.
    systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "!@system";

    hardware.graphics.enable32Bit = true;
  };

  # Rootless Docker daemon (user-level systemd service). No user dep because
  # `virtualisation.docker.rootless` does not scope itself to a named user at
  # the NixOS level — any ordinary account runs its own daemon instance.
  flake.featureMeta.docker = {
    requires = [];
    kind = "service";
    provides = {
      systemBins = ["docker"];
      userUnits = ["docker.service"];
    };
  };

  # feature test: `provides` waits for the tester's daemon; the script then
  # runs a container through it and checks that a system account's instance
  # leaves the unit alone. We stub out hardware.graphics.enable32Bit to avoid
  # pulling in 32-bit Mesa — it has no effect on the daemon in headless CI.
  flake.featureTests.docker = {
    extraNixosModules = [
      ({lib, ...}: {
        hardware.graphics.enable32Bit = lib.mkForce false;

        # Stands in for the greeter: a system account whose systemd instance
        # is up (lingering) without anyone logging in.
        users.groups.sysacct = {};
        users.users.sysacct = {
          isSystemUser = true;
          group = "sysacct";
          home = "/var/lib/sysacct";
          createHome = true;
          linger = true;
        };
      })
    ];
    testScript = ''
      uid = machine.succeed("id -u tester").strip()
      docker = (
          f"sudo -u tester env XDG_RUNTIME_DIR=/run/user/{uid}"
          f" DOCKER_HOST=unix:///run/user/{uid}/docker.sock docker"
      )

      # No registry in the VM: an empty image with the host's store mounted in
      # is enough to prove the daemon can start a container.
      machine.succeed(f"tar c --files-from /dev/null | {docker} import - scratchimg")
      out = machine.succeed(
          f"{docker} run --rm -v /nix/store:/nix/store:ro -v /run/current-system/sw/bin:/bin:ro"
          " scratchimg /bin/sh -c 'echo container-uid=$(id -u)'"
      )
      assert "container-uid=0" in out, out
      # Rootless: the daemon belongs to the tester, not to root.
      machine.succeed(f"{docker} info --format '{{{{.SecurityOptions}}}}' | grep -q rootless")

      # A system account's instance must skip the unit, not start-and-fail it.
      machine.wait_for_unit("default.target", "sysacct")
      info = machine.get_unit_info("docker.service", "sysacct")
      assert info["ConditionResult"] == "no", info["ConditionResult"]
      assert info["ActiveState"] == "inactive", info["ActiveState"]
    '';
  };
}
