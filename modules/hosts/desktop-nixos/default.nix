{config, ...}: let
  modules = [
    "firefox"
    "git"
    "ssh"

    "niri"
    "wiktor"
    "vscode"
    "fish"
  ];
in {
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
