{config, ...}: let
  modules = builtins.fromJSON (builtins.readFile ./features.json);
in {
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
