{
  flake.modules.nixos.wacom = {
    hardware.opentabletdriver.enable = true;
  };

  # No tablet in a VM, but the opentabletdriver daemon/unit still gets configured
  # — assert the unit is installed (the feature wired it up). Actual tablet input
  # is runtimeUntestable.
  flake.featureMeta.wacom = {
    requires = [];
    kind = "service";
    runtimeUntestable = true;
    provides.systemBins = ["otd"];
  };

  # feature test: no tablet in the VM, so the daemon can't be waited on — but
  # the unit must at least be installed. (This is what the comment above the
  # old script promised and never asserted.) opentabletdriver ships a systemd
  # *user* unit, so check both locations rather than assume which.
  flake.featureTests.wacom = {
    testScript = ''
      machine.succeed(
          "test -e /etc/systemd/user/opentabletdriver.service "
          "|| systemctl cat opentabletdriver.service"
      )
    '';
  };
}
