{inputs, ...}: {
  flake.modules.homeManager.spotify = {pkgs, ...}: {
    imports = [inputs.spicetify-nix.homeManagerModules.default];

    programs.spicetify = let
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
    in {
      enable = true;
      enabledExtensions = builtins.attrValues {
        inherit
          (spicePkgs.extensions)
          adblock
          betterGenres
          keyboardShortcut
          volumePercentage
          ;
      };
    };
  };
}
