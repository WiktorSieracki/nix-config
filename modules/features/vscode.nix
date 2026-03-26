{
  flake.modules = {
    nixos.vscode = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        alejandra
      ];
    };

    homeManager.vscode = {pkgs, ...}: {
      programs.vscode = {
        enable = true;

        profiles.default = {
          extensions = with pkgs.vscode-extensions; [
            bbenoist.nix
            jnoortheen.nix-ide
            # vscodevim.vim
          ];
          userSettings = {
            "nix.serverPath" = "nixd";
            "nix.enableLanguageServer" = true;
            "nix.serverSettings" = {
              nixd = {
                formatting = {
                  command = [
                    "alejandra"
                  ];
                };
              };
            };
            "editor.formatOnSave" = true;
            "files.autoSave" = "onFocusChange";
            "git.autofetch" = true;
            "git.confirmSync" = false;
            "explorer.confirmDragAndDrop" = false;
          };
        };
      };
    };
  };
}
