{config, ...}: let
  modules = [
    "wiktor"
    "niri"
    "fish"
    "git"
    "ssh"
    "ssh-server"
    "sops"
    "tailscale"
    "nix"
    "firefox"
    "brave"
    "bruno"
    "vscode"

    "spotify"
    "java"
    "python"
    "discord"
    "nodejs"
    "pre-commit"
    "llm-agents"
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
