{config, ...}: let
  spec = {
    users = ["wiktor"];
    # Everything this machine enables, one list — the file Switchboard edits.
    features = builtins.fromJSON (builtins.readFile ./features.json);
  };
in {
  flake = {
    hostSpecs.vpsNixos = spec;
    nixosConfigurations.vpsNixos = config.flake.lib.mkSystems.linux "vpsNixos";
    modules.nixos."hosts/vpsNixos" = {
      imports = config.flake.lib.loadHost config spec;
    };
  };
}
