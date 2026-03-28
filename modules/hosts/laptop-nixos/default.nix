{config, ...}: let
  modules = [
    "wiktor"
    "niri"
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
    "discord"
    "node"
    "pre-commit"
    "cpp"
    "typst"
    "custom-scripts"
    "docker"

    "eduroam"
  ];
in {
  flake = {
    nixosConfigurations.laptopNixos = config.flake.lib.mkSystems.linux "laptopNixos";
    modules.nixos."hosts/laptopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
