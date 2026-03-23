{pkgs, ...}: {
  imports = [
    ../shared.nix
    ../modules/vscode.nix
    ../modules/noctalia.nix
    ../modules/firefox.nix
  ];

  programs.vscode.profiles.default.extensions = with pkgs.vscode-extensions; [
    vscodevim.vim
  ];
}
