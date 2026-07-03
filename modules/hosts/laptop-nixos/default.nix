{config, ...}: let
  modules = builtins.fromJSON (builtins.readFile ./features.json);
in {
  flake = {
    nixosConfigurations.laptopNixos = config.flake.lib.mkSystems.linux "laptopNixos";
    modules.nixos."hosts/laptopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
