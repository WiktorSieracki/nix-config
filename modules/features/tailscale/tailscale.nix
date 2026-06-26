{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };
  };

  flake.featureMeta.tailscale = {
    requires = [];
    kind = "service";
  };

  flake.probaTests.tailscale = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("tailscaled.service")
    '';
  };
}
