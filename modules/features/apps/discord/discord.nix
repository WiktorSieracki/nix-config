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
    requires = [];
    kind = "gui";
  };

  # Próba: nixpkgs.config.allowUnfree is already true in the outer perSystem pkgs
  # (parts.nix), so no extra module is needed. Binary is `Discord` (capital D).
  flake.featureTests.discord = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v Discord")
    '';
  };
}
