{config, ...}: let
  modules = [
    "wiktor"
    "niri"
    "nvidia"
    "fish"
    "git"
    "ssh"
    "sops"
    "nix"
    "firefox"
    "vscode"

    "spotify"
    "java"
    "python"
    "node"
    "pre-commit"
    "cpp"
    "typst"
    "custom-scripts"
    "docker"
  ];
in {
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
