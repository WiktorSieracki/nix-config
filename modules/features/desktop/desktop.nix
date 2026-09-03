{
  # Graphical-session layer extracted from the old `nixos` base bucket so that
  # `core` (the slimmed `flake.modules.nixos.nixos`) stays truly minimal. This
  # makes the modularity litmus test real: a `cli`/`service` feature's feature test runs
  # on `core` alone, so if it secretly needed the niri desktop the test fails.
  #
  # Hosts that want a GUI enable "desktop"; it `requires` "niri" (the compositor
  # that `defaultSession` points at) — the loader hard-fails otherwise.
  flake.modules.nixos.desktop = {pkgs, ...}: {
    services.xserver.enable = true;
    # SDDM (Qt6, Wayland greeter) instead of stock GDM, left on its native
    # NixOS look: `theme` stays at the module default ("") so the greeter is the
    # plain built-in one with no wallpaper. The themed variant is the opt-in
    # `sddm-theme` feature.
    services.displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
      # The default greeter compositor (weston) starts on NVIDIA but the mouse
      # is dead on the greeter; kwin handles it correctly.
      wayland.compositor = "kwin";
      # The module only sets a cursor theme for the breeze theme; with any
      # other theme — the empty default included — the greeter has none and the
      # pointer is invisible (input still works — verified in the vm host).
      # Match the session's cursor.
      settings.Theme = {
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = 24;
      };
    };
    services.displayManager.defaultSession = "niri";

    # Removable media in Nautilus: udisks2 does the mounting over D-Bus, gvfs
    # provides the volume monitor Nautilus reads its sidebar from. Without both
    # a plugged-in USB stick is invisible in the file manager (it still shows in
    # `lsblk`), and gnome-disk-utility above has no daemon to talk to.
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    environment.systemPackages = with pkgs; [
      bibata-cursors # greeter cursor (settings.Theme.CursorTheme above)
      nautilus
      libreoffice-fresh
      qalculate-gtk
      evince
      file-roller
      vlc
      gnome-disk-utility
      pinta
    ];
  };

  flake.featureMeta.desktop = {
    requires = ["niri"];
    kind = "service";
    provides = {
      units = ["display-manager.service"];
      systemBins = ["niri"];
      files = ["/run/current-system/sw/share/icons/Bibata-Modern-Ice/cursors/left_ptr"];
    };
  };

  # feature test: the desktop layer is present (display-manager exists — the opposite of
  # core-smoke), it's SDDM on its native theme (no wallpaper — the skin lives in
  # the opt-in `sddm-theme` feature), and the niri session it points at is installed.
  flake.featureTests.desktop = {
    testScript = ''
      machine.succeed("systemctl cat display-manager.service | grep -qi sddm")
      # Native greeter: Theme.Current is written but empty. Asserting the empty
      # value (not just the absence of "forest") is what catches a theme
      # sneaking back in via any other feature.
      machine.succeed("grep -Eq '^Current *= *$' /etc/sddm.conf.d/00-nixos.conf")
      # Cursor theme must be configured as well as resolvable (provides.files
      # covers the latter), or the greeter pointer is invisible — mouse input
      # still works, so only this guards it.
      machine.succeed("grep -q 'CursorTheme=Bibata-Modern-Ice' /etc/sddm.conf.d/00-nixos.conf")
    '';
  };
}
