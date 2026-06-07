{config, ...}: let
  modules = [
    # system
    "wiktor"
    "niri"

    # shell & environment
    "fish"
    "nix"
    "sops"
    "tailscale"
    "ssh"
    "ssh-server"
    "pre-commit"
    "custom-scripts"

    # development
    "git"
    "vscode"
    "java"
    "python"
    "nodejs"
    "cpp"
    "typst"
    "docker"
    "llm-agents"
    "bruno"

    # personal
    "personal-snippets"

    # apps
    "firefox"
    "brave"
    "spotify"
    "discord"
    "teams-for-linux"
    "localsend"

    # network
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
