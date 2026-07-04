{
  # Graphical-session layer extracted from the old `nixos` base bucket so that
  # `core` (the slimmed `flake.modules.nixos.nixos`) stays truly minimal. This
  # makes the modularity litmus test real: a `cli`/`service` feature's Próba runs
  # on `core` alone, so if it secretly needed the niri desktop the test fails.
  #
  # Hosts that want a GUI enable "desktop"; it `requires` "niri" (the compositor
  # that `defaultSession` points at) — the loader hard-fails otherwise.
  flake.modules.nixos.desktop = {pkgs, ...}: {
    services.xserver.enable = true;
    # SDDM (Qt6, Wayland greeter) with the astronaut theme instead of stock GDM.
    # The theme package must be in systemPackages so SDDM finds it under
    # /run/current-system/sw/share/sddm/themes; extraPackages puts its Qt/QML
    # deps (qtmultimedia for animated backgrounds) on the greeter's import path.
    services.displayManager.sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      wayland.enable = true;
      # The default greeter compositor (weston) starts on NVIDIA but the mouse
      # is dead on the greeter; kwin handles it correctly.
      wayland.compositor = "kwin";
      # The module only sets a cursor theme for the breeze theme; with any
      # other theme the greeter has none and the pointer is invisible (input
      # still works — verified in the vm host). Match the session's cursor.
      settings.Theme = {
        CursorTheme = "Bibata-Modern-Ice";
        CursorSize = 24;
      };
      theme = "sddm-astronaut-theme";
      extraPackages = with pkgs; [
        sddm-astronaut
        kdePackages.qtmultimedia
      ];
    };
    services.displayManager.defaultSession = "niri";

    environment.systemPackages = with pkgs; [
      sddm-astronaut
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
  };

  # Próba: the desktop layer is present (display-manager exists — the opposite of
  # core-smoke), it's SDDM with the astronaut theme, and the niri session it
  # points at is installed.
  flake.probaTests.desktop = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl cat display-manager.service | grep -qi sddm")
      machine.succeed("grep -q 'Current=sddm-astronaut-theme' /etc/sddm.conf.d/00-nixos.conf")
      machine.succeed("test -e /run/current-system/sw/share/sddm/themes/sddm-astronaut-theme/Main.qml")
      # Cursor theme must be configured AND resolvable, or the greeter pointer
      # is invisible (mouse input still works, so only this guards it).
      machine.succeed("grep -q 'CursorTheme=Bibata-Modern-Ice' /etc/sddm.conf.d/00-nixos.conf")
      machine.succeed("test -e /run/current-system/sw/share/icons/Bibata-Modern-Ice/cursors/left_ptr")
      machine.succeed("command -v niri")
    '';
  };
}
