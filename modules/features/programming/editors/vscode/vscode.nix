{inputs, ...}: {
  flake.niriBinds.vscode = {...}: {
    "Mod+C" = _: {
      props."hotkey-overlay-title" = "Open nix-config in an editor";
      content."spawn-sh" = "code ~/.config/nix-config";
    };
  };

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
          # Guard with `pkgs ? nix4vscode` so the module degrades gracefully
          # when the nix4vscode overlay is not applied (e.g. in the feature test VM
          # where nixpkgs.pkgs is read-only and overlays are ignored).
          extensions =
            if pkgs ? nix4vscode
            then
              pkgs.nix4vscode.forVscode [
                "Noctalia.noctaliatheme"
                # nix
                "bbenoist.nix"
                "jnoortheen.nix-ide"
                # frontend
                "bradlc.vscode-tailwindcss"
                "esbenp.prettier-vscode"
                "dsznajder.es7-react-js-snippets"
                "formulahendry.auto-rename-tag"
                # typst
                "myriad-dreamin.tinymist"
                # misc
                "ms-vscode-remote.remote-containers"
                "ms-vscode-remote.remote-ssh"
                "eamodio.gitlens"
                "GitHub.vscode-pull-request-github"
                "usernamehw.errorlens"
              ]
            else [];
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
            "workbench.editor.tabSizing" = "fixed";
            "remote.SSH.connectTimeout" = 30;
            "remote.SSH.showLoginTerminal" = true;
            "remote.SSH.useExecServer" = false;
            "remote.SSH.useLocalServer" = false;
            "remote.SSH.remotePlatform" = {
              "laptopnixos" = "linux";
              "desktopnixos" = "linux";
            };
            "github.copilot.enable" = {
              "*" = true;
              "plaintext" = false;
              "markdown" = true;
              "scminput" = false;
            };
          };
        };
      };
    };
  };

  flake.featureMeta.vscode = {
    requires = [];
    kind = "gui";
  };

  # nix4vscode extensions are fetched from the VS Code marketplace as
  # fixed-output derivations — skip them in the feature test to keep the VM lean
  # and avoid marketplace network deps at test-build time.
  # The nixos.vscode module sets nixpkgs.overlays but the nixosTest framework
  # injects pkgs as `nixpkgs.pkgs` (read-only), creating a "defined multiple
  # times" conflict. We cancel it with lib.mkForce []. The homeManager.vscode
  # module now guards `pkgs.nix4vscode.forVscode` with `pkgs ? nix4vscode`, so
  # when the overlay is absent extensions gracefully fall back to [].
  flake.featureTests.vscode = {
    extraNixosModules = [
      ({lib, ...}: {
        nixpkgs.overlays = lib.mkForce [];
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-tester.service")
      machine.succeed("su - tester -c 'command -v code'")
    '';
  };
}
