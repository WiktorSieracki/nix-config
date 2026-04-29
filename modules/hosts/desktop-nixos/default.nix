{config, ...}: let
  modules = [
    "wiktor"
    "niri"
    "nvidia"
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
    "llm-agents"
    "docker"
    "handy"
    "affine"
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
