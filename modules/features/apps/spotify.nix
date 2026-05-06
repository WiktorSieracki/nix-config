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
}
