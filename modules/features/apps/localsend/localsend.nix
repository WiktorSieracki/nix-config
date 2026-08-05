{
  flake.modules.nixos.localsend = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      localsend
    ];
    networking.firewall = {
      allowedTCPPorts = [53317];
      allowedUDPPorts = [53317];
    };
  };

  flake.featureMeta.localsend = {
    requires = ["desktop"];
    kind = "gui";
    # localsend's actual executable is `localsend_app` (upstream Flutter naming).
    provides.systemBins = ["localsend_app"];
  };

  # feature test: the firewall ports this feature opens are config-only — nothing
  # listens on them in the VM — so `provides` covers everything assertable.
  flake.featureTests.localsend = {};
}
