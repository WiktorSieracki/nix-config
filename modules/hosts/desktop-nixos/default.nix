{config, ...}: let
  spec = {
    users = ["wiktor"];
    # Everything this machine enables, one list — the file Switchboard edits.
    features = builtins.fromJSON (builtins.readFile ./features.json);
  };
in {
  flake = {
    hostSpecs.desktopNixos = spec;
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadHost config spec;
    };
  };
}
