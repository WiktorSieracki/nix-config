{
  # Graphical-session layer extracted from the old `nixos` base bucket so that
  # `core` (the slimmed `flake.modules.nixos.nixos`) stays truly minimal. This
  # makes the modularity litmus test real: a `cli`/`service` feature's Próba runs
  # on `core` alone, so if it secretly needed the niri desktop the test fails.
  #
  # Hosts that want a GUI enable "desktop"; it `requires` "niri" (the compositor
  # that `defaultSession` points at) — the loader hard-fails otherwise.
  flake.modules.nixos.desktop = {pkgs, ...}: let
    # qylock's "forest" SDDM theme — visually close to the noctalia lockscreen,
    # so greeter and locker read as one screen. Only this theme is fetched
    # (sparse checkout): the full repo carries 40+ themes with mp4 backgrounds.
    qylock-forest = pkgs.stdenvNoCC.mkDerivation {
      pname = "qylock-forest-sddm-theme";
      version = "0-unstable-2026-06-05";
      src = pkgs.fetchFromGitHub {
        owner = "Darkkal44";
        repo = "qylock";
        rev = "db61a972b4b23728d9944a906e70029ca8a5899d";
        sparseCheckout = ["themes/forest"];
        hash = "sha256-Dj2a2uKsriYbh+ySG84VpVCTbarPTra9U+1ITE7sX6U=";
      };
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/sddm/themes
        cp -r themes/forest $out/share/sddm/themes/forest
        runHook postInstall
      '';
    };
  in {
    services.xserver.enable = true;
    # SDDM (Qt6, Wayland greeter) with the qylock forest theme instead of stock
    # GDM. The theme package must be in systemPackages so SDDM finds it under
    # /run/current-system/sw/share/sddm/themes; extraPackages puts its Qt/QML
    # deps on the greeter's import path (qtmultimedia for the video background,
    # qt5compat for Qt5Compat.GraphicalEffects which Main.qml imports).
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
      theme = "forest";
      extraPackages = with pkgs; [
        kdePackages.qtmultimedia
        kdePackages.qt5compat
      ];
    };
    services.displayManager.defaultSession = "niri";

    environment.systemPackages = with pkgs; [
      qylock-forest
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
  # core-smoke), it's SDDM with the qylock forest theme, and the niri session it
  # points at is installed.
  flake.probaTests.desktop = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("systemctl cat display-manager.service | grep -qi sddm")
      machine.succeed("grep -q 'Current=forest' /etc/sddm.conf.d/00-nixos.conf")
      machine.succeed("test -e /run/current-system/sw/share/sddm/themes/forest/Main.qml")
      # The theme is a video background (bg.mp4) plus QML that imports
      # QtMultimedia and Qt5Compat.GraphicalEffects; a missing QML dep makes the
      # greeter fall back to a bare screen with no eval error, so assert the
      # greeter env (built from sddm + extraPackages) carries both modules.
      machine.succeed("test -e /run/current-system/sw/share/sddm/themes/forest/bg.mp4")
      # The wrapped greeter binary embeds its QML import paths, so a binary grep
      # proves the modules are on the greeter's path.
      machine.succeed("grep -aq qt5compat /run/current-system/sw/bin/sddm-greeter-qt6")
      machine.succeed("grep -aq qtmultimedia /run/current-system/sw/bin/sddm-greeter-qt6")
      # Cursor theme must be configured AND resolvable, or the greeter pointer
      # is invisible (mouse input still works, so only this guards it).
      machine.succeed("grep -q 'CursorTheme=Bibata-Modern-Ice' /etc/sddm.conf.d/00-nixos.conf")
      machine.succeed("test -e /run/current-system/sw/share/icons/Bibata-Modern-Ice/cursors/left_ptr")
      machine.succeed("command -v niri")
    '';
  };
}
