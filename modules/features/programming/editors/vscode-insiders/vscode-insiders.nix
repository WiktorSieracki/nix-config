{...}: {
  # Installed as a system package rather than via home-manager: stable VS Code
  # already lives in the home-manager profile and shares `lib/vscode/` paths,
  # which collide in buildEnv. Keeping Insiders in the system profile avoids that.
  flake.modules.nixos.vscode-insiders = {pkgs, ...}: let
    # nixpkgs only packages stable VS Code, so we point the same builder at the
    # daily Insiders tarball. Bump the hash when the build needs refreshing:
    #   nix store prefetch-file --name vscode-insiders.tar.gz \
    #     https://update.code.visualstudio.com/latest/linux-x64/insider
    vscode-insiders = (pkgs.vscode.override {isInsiders = true;}).overrideAttrs (old: {
      version = "latest";
      src = pkgs.fetchurl {
        name = "VSCode-insiders-linux-x64.tar.gz";
        url = "https://update.code.visualstudio.com/latest/linux-x64/insider";
        hash = "sha256-vo6EUyOW3yWx+rhkN55RhRtQb3iGYaIf+t+kbrX3A+g=";
      };
      # The bundled Copilot extension ships a `computer.node` native module that
      # pulls in libraries the stable VS Code build doesn't need.
      buildInputs =
        (old.buildInputs or [])
        ++ (with pkgs; [
          libxtst
          libjpeg8
          pipewire
          libei
        ]);
    });
  in {
    environment.systemPackages = [vscode-insiders];
  };

  flake.featureMeta.vscode-insiders = {
    requires = [];
    kind = "gui";
  };

  flake.probaTests.vscode-insiders = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v code-insiders")
    '';
  };
}
