{ inputs, pkgs, ... }:

{
  programs.vscode = {
    enable = true;
    package = pkgs.vscode;

    profiles.default = {
      # VS Code extensions
      extensions = with pkgs.vscode-extensions; [

      ];

      # VS Code settings
      #userSettings = {
      #  "editor.formatOnSave" = true;
      #};
    };
  };
}
