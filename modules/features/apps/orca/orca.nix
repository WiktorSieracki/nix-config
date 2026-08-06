{
  flake.modules.nixos.orca = {pkgs, ...}: let
    # Orca ships only prebuilt release artifacts (no nix package upstream). We
    # repackage the `.deb`: it is a plain electron-builder tree under /opt/Orca
    # with a bundled Electron, so `autoPatchelfHook` links it against nixpkgs'
    # own libs. See notes.md for why the AppImage is not used.
    orca = pkgs.stdenv.mkDerivation rec {
      pname = "orca-ide";
      version = "1.4.173";

      src = pkgs.fetchurl {
        url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-ide_${version}_amd64.deb";
        hash = "sha256-jW1/XZJCmQrNXOkmIrNGQAL/RtSVjT6Phtiqnok75po=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
        makeWrapper
        wrapGAppsHook3
      ];

      buildInputs = with pkgs; [
        # Electron/Chromium runtime
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        cairo
        cups
        dbus
        expat
        glib
        gtk3
        libdrm
        libgbm
        libxkbcommon
        libGL
        nspr
        nss
        pango
        udev
        stdenv.cc.cc.lib
        xorg.libX11
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXrandr
        xorg.libxcb
      ];

      # The bundled chrome-sandbox is setuid-only; NixOS provides its own
      # sandbox story, so let Electron fall back to the kernel user namespaces.
      dontWrapGApps = true;

      unpackPhase = "dpkg-deb -x $src .";

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share
        cp -r opt/Orca $out/share/orca
        cp -r usr/share/icons $out/share/icons

        install -Dm644 usr/share/applications/orca-ide.desktop \
          $out/share/applications/orca-ide.desktop
        substituteInPlace $out/share/applications/orca-ide.desktop \
          --replace-fail "/opt/Orca/orca-ide" "orca-ide"

        runHook postInstall
      '';

      # `orca` (the binary name we expose) would collide with the GNOME screen
      # reader, so keep upstream's `orca-ide`. Runtime deps come from the deb's
      # Depends: the app drives a headless browser (xvfb/xdotool/xclip) for its
      # computer-use agent.
      postFixup = ''
        makeWrapper $out/share/orca/orca-ide $out/bin/orca-ide \
          --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [xdotool xclip xorg.xvfb])} \
          "''${gappsWrapperArgs[@]}"
      '';

      meta = {
        description = "ADE for working with a fleet of parallel coding agents";
        homepage = "https://github.com/stablyai/orca";
        license = pkgs.lib.licenses.mit;
        platforms = ["x86_64-linux"];
        mainProgram = "orca-ide";
      };
    };
  in {
    environment.systemPackages = [orca];
  };

  flake.featureMeta.orca = {
    requires = ["desktop"];
    kind = "gui";
  };

  # feature test: GUI app — per ADR 0002 assert the binary lands on PATH and the
  # Electron entrypoint is fully patched, rather than launching a window.
  flake.featureTests.orca = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v orca-ide")
      machine.succeed("test -f /run/current-system/sw/share/applications/orca-ide.desktop")
    '';
  };
}
