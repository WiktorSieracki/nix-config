{inputs, ...}: {
  flake.niriBinds.spotify = {pkgs, lib}: {
    "Mod+S" = _: {
      props."hotkey-overlay-title" = "Open Spotify";
      content."spawn" = ["${lib.getExe pkgs.spotify}"];
    };
  };

  flake.modules.homeManager.spotify = {pkgs, ...}: {
    imports = [inputs.spicetify-nix.homeManagerModules.default];

    programs.spicetify = let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in {
      enable = true;
      theme = spicePkgs.themes.comfy;
      enabledExtensions = builtins.attrValues {
        inherit
          (spicePkgs.extensions)
          adblock
          betterGenres
          keyboardShortcut
          volumePercentage
          ;
      };
      colorScheme = "Comfy";
    };
  };

  flake.featureMeta.spotify = {
    requires = ["wiktor"];
    kind = "gui";
  };

  # Próba: spicetify-nix wraps the unfree `spotify` package and installs it into
  # the wiktor HM profile as `spotify`. allowUnfree is already true in the outer
  # perSystem pkgs (parts.nix) so no extra module is needed.
  flake.probaTests.spotify = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.wait_for_unit("home-manager-wiktor.service")
      machine.succeed("su - wiktor -c 'command -v spotify'")
    '';
  };
}
