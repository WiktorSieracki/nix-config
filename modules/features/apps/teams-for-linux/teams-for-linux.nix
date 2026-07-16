{
  flake.niriBinds.teams = {pkgs, lib}: {
    "Mod+T" = _: {
      props."hotkey-overlay-title" = "Open Teams";
      content."spawn" = ["${lib.getExe pkgs.teams-for-linux}"];
    };
  };

  flake.modules.nixos.teams-for-linux = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      teams-for-linux
    ];
  };

  flake.featureMeta.teams-for-linux = {
    requires = ["desktop"];
    kind = "gui";
  };

  flake.featureTests.teams-for-linux = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v teams-for-linux")
    '';
  };
}
