{config, ...}: let
  spec = builtins.fromJSON (builtins.readFile ./features.json);
in {
  flake = {
    hostSpecs.laptopNixos = spec;
    nixosConfigurations.laptopNixos = config.flake.lib.mkSystems.linux "laptopNixos";
    modules.nixos."hosts/laptopNixos" = {
      imports = config.flake.lib.loadHost config spec;
    };
  };
}
