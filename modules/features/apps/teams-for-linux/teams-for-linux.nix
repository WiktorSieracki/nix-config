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
    provides.systemBins = ["teams-for-linux"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.teams-for-linux = {};
}
