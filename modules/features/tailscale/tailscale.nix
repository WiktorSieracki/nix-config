{
  flake.modules.nixos.tailscale = {
    services.tailscale = {
      enable = true;
      useRoutingFeatures = "client";
      # Let the wiktor user run `tailscale serve/funnel` without sudo:
      # t3code-server publishes itself on the tailnet with `tailscale serve`
      # from its user unit (see hosts/vps-nixos/notes.md for what breaks when
      # the operator is reset).
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
