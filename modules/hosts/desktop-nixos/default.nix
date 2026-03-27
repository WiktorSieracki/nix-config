{config, ...}: let
  modules = [
    "firefox"
    "git"
    "ssh"
    "nvidia"
    "spotify"

    "niri"
    "java"
    "nix"
    "wiktor"
    "vscode"
    "fish"
    "cpp"
  ];
in {
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
