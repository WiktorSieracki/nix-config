{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      # Let the wiktor user run `tailscale funnel/serve` without sudo
      # (required by agents-of-empire's Tailscale Funnel transport).
      extraSetFlags = ["--operator=wiktor"];
    };
  };

  flake.featureMeta.tailscale = {
    requires = [];
    kind = "service";
  };

  flake.featureTests.tailscale = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("tailscaled.service")
    '';
  };
}
