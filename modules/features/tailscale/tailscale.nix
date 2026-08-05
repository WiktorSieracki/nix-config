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
    provides = {
      units = ["tailscaled.service"];
      systemBins = ["tailscale"];
    };
  };

  # feature test: joining a tailnet needs a real auth key, so the daemon coming
  # up and the CLI being reachable is as far as a VM goes.
  flake.featureTests.tailscale = {};
}
