{config, ...}: let
  modules = [
    # system
    "wiktor"
    "niri"
    "nvidia"

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
    "zeditor"
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

    # workspaces
    "sending-cv"

    # apps
    "firefox"
    "brave"
    "chromium"
    "spotify"
    "discord"
    "teams-for-linux"
    "handy"
    "affine"
    "localsend"

    # network
    "home-wifi"

    # hardware
    "wacom"
  ];
in {
  flake = {
    nixosConfigurations.desktopNixos = config.flake.lib.mkSystems.linux "desktopNixos";
    modules.nixos."hosts/desktopNixos" = {
      imports = config.flake.lib.loadNixosAndHmModuleForUser config modules;
    };
  };
}
