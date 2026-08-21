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

    homeManager.vscode = {
      pkgs,
      lib,
      ...
    }: let
      # The Noctalia theme extension is deliberately NOT in the HM extension
      # list below — see home.activation.noctaliaVscodeTheme.
      noctaliaTheme =
        if pkgs ? nix4vscode
        then lib.head (pkgs.nix4vscode.forVscode ["Noctalia.noctaliatheme"])
        else null;
    in {
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

      # The Noctalia VS Code theme is a *rendered* artifact, not a static
      # extension: noctalia's `code` template rewrites the extension's
      # NoctaliaTheme-color-theme.json with the active colour scheme. Two things
      # make the plain HM install useless for that:
      #   - noctalia only looks at dirs matching `noctalia.noctaliatheme-`
      #     (Scripts/python/src/theming/vscode-helper.py, trailing dash), while
      #     HM installs to the unversioned `noctalia.noctaliatheme`;
      #   - the HM entry is a symlink into the store, so the render can't write.
      # Result on a fresh home: VS Code loads the theme's shipped placeholder
      # navy (#070722) instead of the scheme's colours, forever.
      # So we install this one extension ourselves, as a writable versioned copy.
      # The colour file is only seeded when missing — an activation must never
      # clobber what noctalia already rendered into it.
      home.activation = lib.mkIf (noctaliaTheme != null) {
        noctaliaVscodeTheme = lib.hm.dag.entryAfter ["writeBoundary"] ''
          src=${noctaliaTheme}/share/vscode/extensions/noctalia.noctaliatheme
          dst="$HOME/.vscode/extensions/noctalia.noctaliatheme-${noctaliaTheme.version}"
          theme="$dst/themes/NoctaliaTheme-color-theme.json"

          run rm -rf "$dst.new"
          if [ -e "$theme" ]; then
            run cp -r --no-preserve=mode,ownership -T "$src" "$dst.new"
            run rm -f "$dst.new/themes/NoctaliaTheme-color-theme.json"
            run cp -a "$theme" "$dst.new/themes/NoctaliaTheme-color-theme.json"
            run rm -rf "$dst"
            run mv "$dst.new" "$dst"
          else
            run rm -rf "$dst"
            run cp -r --no-preserve=mode,ownership -T "$src" "$dst"
          fi
          run chmod -R u+w "$dst"
        '';
      };
    };
  };

  flake.featureMeta.vscode = {
    requires = ["desktop"];
    kind = "gui";
    provides.userBins = ["code"];
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
  };
}
