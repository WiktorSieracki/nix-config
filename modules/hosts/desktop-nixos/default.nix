{config, ...}: let
  spec = builtins.fromJSON (builtins.readFile ./features.json);
in {
  flake = {
    hostSpecs.desktopNixos = spec;
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadHost config spec;
    };
  };
}
