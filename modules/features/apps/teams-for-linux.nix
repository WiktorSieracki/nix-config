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
}
