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
    "nodejs"
    "pre-commit"
    "cpp"
    "typst"
    "custom-scripts"
    "docker"
    "opencode"

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
