{
  flake.niriBinds.discord = {pkgs, lib}: {
    "Mod+D" = _: {
      props."hotkey-overlay-title" = "Open Discord";
      content."spawn" = ["${lib.getExe pkgs.discord}"];
    };
  };

  flake.modules.nixos.discord = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      discord
    ];
  };

  flake.featureMeta.discord = {
    requires = ["desktop"];
    kind = "gui";
    # Binary is `Discord` (capital D).
    provides.systemBins = ["Discord"];
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem pkgs
  # (parts.nix), so no extra module is needed.
  flake.featureTests.discord = {};
}
