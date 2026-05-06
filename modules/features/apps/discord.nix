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
}
