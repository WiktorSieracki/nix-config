{
  # Know about dying hardware before it dies, and keep firmware patched.
  #
  # - smartd watches every SMART-capable disk and raises a desktop notification
  #   (through systembus-notify) plus a wall message when one starts failing.
  # - fwupd delivers BIOS/SSD/dock firmware from LVFS (`fwupdmgr refresh &&
  #   fwupdmgr update`); its refresh timer keeps the metadata current.
  flake.modules.nixos.hardware-health = {pkgs, ...}: {
    # smartctl, for looking at a disk by hand (`smartctl -a /dev/nvme0`).
    environment.systemPackages = [pkgs.smartmontools];

    services.smartd = {
      enable = true;
      notifications = {
        wall.enable = true;
        systembus-notify.enable = true;
      };
    };

    services.fwupd.enable = true;
  };

  flake.featureMeta.hardware-health = {
    kind = "service";
    provides = {
      units = ["smartd.service"];
      systemBins = ["smartctl" "fwupdmgr"];
    };
  };

  # feature test: a virtio disk has no SMART, and smartd exits when it finds
  # nothing to watch — so the VM gets an emulated NVMe drive, which QEMU gives a
  # real SMART health log. That lets the test check smartd actually picked a
  # disk up, not merely that it was installed. A real disk failure can't be
  # staged, so the test fires smartd's own notify hook with a fake warning and
  # watches the system bus for the signal systembus-notify turns into a
  # desktop notification.
  flake.featureTests.hardware-health = {
    extraNixosModules = [
      {
        virtualisation.qemu.options = [
          "-blockdev driver=null-co,node-name=smartnvme,size=1073741824"
          "-device nvme,serial=hwhealth0,drive=smartnvme"
        ];
      }
    ];
    testScript = ''
      machine.succeed("smartctl -H /dev/nvme0 | grep -q PASSED")
      machine.wait_until_succeeds("journalctl -u smartd | grep -q 'Monitoring .* 1 NVMe devices'")

      conf = machine.succeed("systemctl cat smartd.service | grep -o '/nix/store/[^ ]*smartd.conf' | head -1").strip()
      hook = machine.succeed(f"grep -o '/nix/store/[^ ]*smartd-notify.sh' {conf} | head -1").strip()
      # dbus-monitor isn't on PATH; take it from the dbus the hook itself uses.
      dbus_bin = machine.succeed(f"grep -o '/nix/store/[^ ]*/bin/dbus-send' {hook} | head -1").strip().removesuffix("/dbus-send")
      machine.succeed(
          "systemd-run --unit busmon sh -c"
          f" '{dbus_bin}/dbus-monitor --system interface=net.nuetzlich.SystemNotifications > /tmp/busmon.log'"
      )
      # Retried, so a hook fired before the monitor attached isn't a failure.
      machine.wait_until_succeeds(
          f"SMARTD_DEVICESTRING=/dev/fake SMARTD_MESSAGE='staged failure' {hook};"
          " grep -q 'Problem detected with disk: /dev/fake' /tmp/busmon.log",
          timeout=60,
      )
      machine.succeed("systemctl start fwupd.service")
      machine.succeed("fwupdmgr --version")
    '';
  };
}
