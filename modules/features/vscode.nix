{inputs, ...}: {
  flake.modules = {
    nixos.vscode = {pkgs, ...}: {
      nixpkgs.overlays = [
        inputs.nix4vscode.overlays.default
      ];

      environment.systemPackages = with pkgs; [
        alejandra
      ];
    };

    homeManager.vscode = {pkgs, ...}: {
      programs.vscode = {
        enable = true;

        profiles.default = {
          extensions = pkgs.nix4vscode.forVscode [
            "Noctalia.noctaliatheme"
            "bbenoist.nix"
            "jnoortheen.nix-ide"
            "bradlc.vscode-tailwindcss"
            "esbenp.prettier-vscode"
            "ms-vscode-remote.remote-containers"
            "dsznajder.es7-react-js-snippets"
            "formulahendry.auto-rename-tag"
            "myriad-dreamin.tinymist"
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
            "[typescriptreact]" = {
              "editor.defaultFormatter" = "esbenp.prettier-vscode";
            };
            "workbench.colorTheme" = "NoctaliaTheme";
          };
        };
      };
    };
  };
}
