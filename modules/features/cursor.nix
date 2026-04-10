{
  flake.modules.homeManager.homeManager = {pkgs, ...}: {
    home.packages = [pkgs.bibata-cursors];

    gtk = {
      enable = true;
      colorScheme = "dark";
      gtk4.theme = null;
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };
    };

    home.pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
  };
}
