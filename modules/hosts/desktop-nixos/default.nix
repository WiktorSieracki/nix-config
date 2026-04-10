{ config, ... }:
let
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
    "brave"
    "chromium"
    "vscode"

    "spotify"
    "discord"
    "java"
    "python"
    "nodejs"
    "pre-commit"
    "cpp"
    "typst"
    "custom-scripts"
    "docker"
    "opencode"
    "handy"
  ];
in
{
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
