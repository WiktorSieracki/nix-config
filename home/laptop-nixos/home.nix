{config, ...}: {
  imports = [
    # ../shared.nix
    ../../modules/vscode.nix
  ];

  home.username = "wiktor";
  home.homeDirectory = "/home/wiktor";
  home.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;
}
