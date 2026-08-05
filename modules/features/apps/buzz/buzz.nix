{
  flake.modules.nixos.buzz = {pkgs, ...}: let
    # buzz ships only prebuilt release binaries (Hermit/just upstream, no nix
    # package). We package the .deb rather than the AppImage: the .deb carries
    # *no* bundled libraries (just the binaries, depending on the system
    # libwebkit2gtk-4.1 + libgtk-3), so autoPatchelf links it against nixpkgs'
    # own webkitgtk. The AppImage route is a dead end here — see notes.md.
    buzz = pkgs.stdenv.mkDerivation rec {
      pname = "buzz";
      version = "0.4.26";

      src = pkgs.fetchurl {
        url = "https://github.com/block/buzz/releases/download/v${version}/Buzz_${version}_amd64.deb";
        hash = "sha256-G1IHVuz8KK2BmBos1cxmiPeF9Eez9djVU1RJBvWb9SE=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
        wrapGAppsHook3
      ];

      buildInputs = with pkgs; [
        webkitgtk_4_1
        gtk3
        glib
        cairo
        pango
        gdk-pixbuf
        atk
        libsoup_3
        openssl
        zlib
        alsa-lib
        stdenv.cc.cc.lib
      ];

      # TLS backend for glib/libsoup — without it https requests fail at runtime.
      runtimeDependencies = [pkgs.glib-networking];

      unpackPhase = "dpkg-deb -x $src .";

      installPhase = ''
        runHook preInstall
        mkdir -p $out
        cp -r usr/bin $out/bin
        cp -r usr/share $out/share
        runHook postInstall
      '';

      # webkit's media backend needs the GStreamer plugins on its search path;
      # gst-libav supplies the AAC decoder the app uses for notification sounds.
      # NOTE: this must be appended in preFixup — setting `gappsWrapperArgs` as a
      # derivation attribute silently does nothing (wrapGAppsHook reads it as a
      # bash array, not an env string).
      preFixup = ''
        gappsWrapperArgs+=(
          --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${pkgs.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
          gst-plugins-bad
          gst-libav
        ])}"
        )
      '';
    };
  in {
    environment.systemPackages = [buzz];
  };

  flake.featureMeta.buzz = {
    requires = ["desktop"];
    kind = "gui";
  };

  # feature test: GUI app — assert the binaries land on PATH (per ADR 0002, don't
  # launch a window in the VM). `buzz` is the CLI, `buzz-desktop` the GUI.
  flake.featureTests.buzz = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v buzz")
      machine.succeed("command -v buzz-desktop")
    '';
  };
}
