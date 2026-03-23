{pkgs, ...}: {
  imports = [
    ../shared.nix
    ../modules/vscode.nix
    # ../modules/noctalia.nix
    ../modules/firefox.nix
  ];

  programs.vscode = {
    enable = true;
    package = pkgs.vscode.override {
      commandLineArgs = [
        "--ozone-platform=x11"
      ];
    };
  };
}
