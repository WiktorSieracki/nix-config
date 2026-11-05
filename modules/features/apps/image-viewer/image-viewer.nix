let
  # Image types Loupe declares in its .desktop file. Without an explicit
  # default, GLib falls back to the most recently *added* association, which is
  # how a single "Open With → Code" sent every PNG to VS Code.
  imageTypes = [
    "image/apng"
    "image/avif"
    "image/bmp"
    "image/gif"
    "image/heic"
    "image/jp2"
    "image/jpeg"
    "image/jxl"
    "image/png"
    "image/qoi"
    "image/svg+xml"
    "image/svg+xml-compressed"
    "image/tiff"
    "image/vnd.microsoft.icon"
    "image/webp"
    "image/x-portable-anymap"
    "image/x-tga"
  ];
in {
  # Loupe (GNOME's image viewer) as the default for images, plus Sushi —
  # Nautilus' Space-bar quick preview for images, PDFs, video, audio and text.
  flake.modules.nixos.image-viewer = {
    pkgs,
    lib,
    ...
  }: {
    environment.systemPackages = [pkgs.loupe];
    services.gnome.sushi.enable = true;
    # System-wide /etc/xdg/mimeapps.list: a user's own ~/.config/mimeapps.list
    # still wins, so a per-user "Open With → Set as default" keeps working.
    xdg.mime.defaultApplications = lib.genAttrs imageTypes (_: "org.gnome.Loupe.desktop");
  };

  flake.featureMeta.image-viewer = {
    requires = ["desktop"];
    kind = "gui";
    provides = {
      systemBins = ["loupe"];
      files = ["/etc/xdg/mimeapps.list"];
    };
  };

  flake.featureTests.image-viewer = {
    testScript = ''
      # GLib resolves the default through mimeapps.list, not the .desktop file.
      machine.succeed("grep -qx 'image/png=org.gnome.Loupe.desktop' /etc/xdg/mimeapps.list")
      machine.succeed("grep -qx 'image/jpeg=org.gnome.Loupe.desktop' /etc/xdg/mimeapps.list")
      machine.succeed("test -e /run/current-system/sw/share/applications/org.gnome.Loupe.desktop")
      # Nautilus finds Sushi over D-Bus activation; no service file, no preview.
      machine.succeed("test -e /run/current-system/sw/share/dbus-1/services/org.gnome.NautilusPreviewer.service")
    '';
  };
}
