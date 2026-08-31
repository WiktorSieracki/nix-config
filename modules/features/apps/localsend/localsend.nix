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

  # Autostart: localsend only receives while it is running, so the session brings
  # it up itself. `--hidden` starts it straight into the tray instead of popping
  # a window over the workspace on every login — the noctalia bar's Tray widget
  # is what makes it reachable again.
  flake.niriSpawnAtStartup.localsend = {pkgs, lib}: "${pkgs.writeShellScript "localsend-hidden" "exec ${lib.getExe' pkgs.localsend "localsend_app"} --hidden"}";

  flake.featureMeta.localsend = {
    requires = ["desktop"];
    kind = "gui";
    # localsend's actual executable is `localsend_app` (upstream Flutter naming).
    provides.systemBins = ["localsend_app"];
  };

  # feature test: the firewall ports this feature opens are config-only — nothing
  # listens on them in the VM — so `provides` covers everything assertable. The
  # autostart entry lives inside the niri wrapper's config, not in a host file,
  # so it is not declarable as `provides` either.
  flake.featureTests.localsend = {};
}
