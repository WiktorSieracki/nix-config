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
  };

  # feature test: binary present on PATH; localsend's actual executable is `localsend_app`
  # (upstream Flutter naming). Firewall ports are config-only, not runtime-testable.
  flake.featureTests.localsend = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v localsend_app")
    '';
  };
}
