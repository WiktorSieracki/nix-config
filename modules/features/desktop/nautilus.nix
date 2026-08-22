{
  flake.niriBinds.nautilus = {pkgs, lib}: {
    "Mod+E" = _: {
      props."hotkey-overlay-title" = "Open file manager: Nautilus";
      content."spawn" = "${lib.getExe pkgs.nautilus}";
    };
  };

  # Nautilus opens as a centred floating popup rather than a tiled column.
  # niri centres new floating windows by default, so only the size is declared.
  flake.niriWindowRules.nautilus = _: {
    matches = [{app-id = "^org\\.gnome\\.Nautilus$";}];
    open-floating = true;
    default-column-width.proportion = 0.5;
    default-window-height.proportion = 0.6;
  };
}
