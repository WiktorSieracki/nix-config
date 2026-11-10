{inputs, ...}: let
  # One spicetify config for both consumers below. The home-manager module
  # installs the build it describes; the Mod+S bind must launch that same
  # build. It used to launch plain `pkgs.spotify` — a different derivation, so
  # the keybind opened Spotify without the Comfy theme and without adblock.
  spiceConfig = pkgs: let
    spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  in {
    enable = true;
    theme = spicePkgs.themes.comfy;
    enabledExtensions = builtins.attrValues {
      inherit
        (spicePkgs.extensions)
        adblock
        keyboardShortcut
        volumePercentage
        ;
    };
    colorScheme = "Comfy";
  };
in {
  flake.niriBinds.spotify = {
    pkgs,
    lib,
  }: {
    "Mod+S" = _: {
      props."hotkey-overlay-title" = "Open Spotify";
      content."spawn" = ["${lib.getExe (inputs.spicetify-nix.lib.mkSpicetify pkgs (spiceConfig pkgs))}"];
    };
  };

  flake.modules.homeManager.spotify = {pkgs, ...}: {
    imports = [inputs.spicetify-nix.homeManagerModules.default];

    programs.spicetify = spiceConfig pkgs;
  };

  flake.featureMeta.spotify = {
    requires = ["desktop"];
    kind = "gui";
    # spicetify-nix wraps the unfree `spotify` package into the HM profile.
    provides.userBins = ["spotify"];
  };

  # feature test: allowUnfree is already true in the outer perSystem pkgs
  # (parts.nix), so no extra module is needed.
  flake.featureTests.spotify = {};
}
