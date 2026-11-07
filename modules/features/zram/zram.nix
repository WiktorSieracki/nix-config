{
  # Memory-pressure safety net for the workstations. A `nix flake check` on
  # the desktop eats all RAM (exit 137), and without this the whole session
  # stalls in disk swap first. zram swap gives compressed RAM before the disk
  # swap is touched (zram gets priority 5, disk swap stays below it), and
  # systemd-oomd kills the offending user cgroup on sustained memory pressure
  # instead of letting the kernel OOM killer pick a random victim late.
  flake.modules.nixos.zram = {lib, ...}: {
    zramSwap = {
      enable = true;
      algorithm = lib.mkDefault "zstd";
      memoryPercent = lib.mkDefault 50;
    };
    # oomd itself is on by default on NixOS but watches nothing; this makes it
    # act on user@.service slices (where `nix eval`, browsers and agents run).
    systemd.oomd.enableUserSlices = true;
  };

  flake.featureMeta.zram = {
    requires = [];
    kind = "config";
    provides.units = ["systemd-oomd.service"];
  };

  flake.featureTests.zram.testScript = ''
    machine.wait_until_succeeds("swapon --show=NAME --noheadings | grep -q zram0")
    machine.succeed("systemctl show user.slice -p ManagedOOMMemoryPressure | grep -qx 'ManagedOOMMemoryPressure=kill'")
  '';
}
