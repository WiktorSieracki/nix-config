{
  # Opt-in greeter skin. `desktop` ships the stock, wallpaper-less SDDM greeter
  # (NixOS default theme); this feature is the toggle that swaps it for qylock's
  # "forest" theme — visually close to the noctalia lockscreen, so greeter and
  # locker read as one screen. Enable it by listing "sddm-theme" in a host's
  # features.json `system` list; remove it to go back to native.
  flake.modules.nixos.sddm-theme = {pkgs, ...}: let
    # Only this theme is fetched (sparse checkout): the full repo carries 40+
    # themes with mp4 backgrounds.
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
    # The theme package must be in systemPackages so SDDM finds it under
    # /run/current-system/sw/share/sddm/themes; extraPackages puts its Qt/QML
    # deps on the greeter's import path (qtmultimedia for the video background,
    # qt5compat for Qt5Compat.GraphicalEffects which Main.qml imports).
    services.displayManager.sddm = {
      theme = "forest";
      extraPackages = with pkgs; [
        kdePackages.qtmultimedia
        kdePackages.qt5compat
      ];
    };

    environment.systemPackages = [qylock-forest];
  };

  flake.featureMeta.sddm-theme = {
    requires = ["desktop"];
    kind = "config";
    provides.files = [
      "/run/current-system/sw/share/sddm/themes/forest/Main.qml"
      "/run/current-system/sw/share/sddm/themes/forest/bg.mp4"
    ];
  };

  # feature test: the theme is actually selected (not just installed), and the
  # QML deps its Main.qml imports are on the greeter's import path — a missing
  # one makes the greeter fall back to a bare screen with no eval error. The
  # wrapped greeter binary embeds its QML import paths, so a binary grep proves
  # the modules are there.
  flake.featureTests.sddm-theme = {
    testScript = ''
      machine.succeed("grep -q 'Current=forest' /etc/sddm.conf.d/00-nixos.conf")
      machine.succeed("grep -aq qt5compat /run/current-system/sw/bin/sddm-greeter-qt6")
      machine.succeed("grep -aq qtmultimedia /run/current-system/sw/bin/sddm-greeter-qt6")
    '';
  };
}
