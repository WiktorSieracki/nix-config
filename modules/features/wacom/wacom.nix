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
  };

  flake.probaTests.wacom = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v otd")
    '';
  };
}
