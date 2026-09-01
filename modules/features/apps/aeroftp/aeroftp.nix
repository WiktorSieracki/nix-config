{
  flake.modules.nixos.aeroftp = {pkgs, ...}: let
    # AeroFTP ships only prebuilt releases (Tauri 2, no nix package). We package
    # the .deb rather than the AppImage — same reasoning as buzz: the .deb bundles
    # no libraries, so autoPatchelf links it against nixpkgs' own webkitgtk/gtk.
    aeroftp = pkgs.stdenv.mkDerivation rec {
      pname = "aeroftp";
      version = "4.1.9";

      src = pkgs.fetchurl {
        url = "https://github.com/axpdev-lab/aeroftp/releases/download/v${version}/AeroFTP_${version}_amd64.deb";
        hash = "sha256-8PvdPeaF10m31s4eWKRMelgY4XhdznMVZQZQOFnxh6w=";
      };

      nativeBuildInputs = with pkgs; [
        dpkg
        autoPatchelfHook
        wrapGAppsHook3
        copyDesktopItems
      ];

      buildInputs = with pkgs; [
        webkitgtk_4_1
        gtk3
        glib
        cairo
        gdk-pixbuf
        libsoup_3
        dbus
        acl
        zlib
        stdenv.cc.cc.lib
      ];

      # glib-networking is the TLS backend libsoup uses; without it every https
      # transfer (and the whole cloud-provider half of the app) fails at runtime.
      # libayatana-appindicator is dlopen'd for the tray, so autoPatchelf can't
      # see it in NEEDED.
      runtimeDependencies = with pkgs; [
        glib-networking
        libayatana-appindicator
      ];

      unpackPhase = "dpkg-deb -x $src .";

      # `usr/bin/aeroftp` is not the app: it is a small Rust dispatcher that finds
      # the real binaries at `../lib/aeroftp` relative to /proc/self/exe (falling
      # back to /usr/lib/aeroftp), then execs `aeroftp.bin` (GUI) or `aeroftp-cli`
      # depending on argv[0] and the subcommand. Putting the dispatcher in
      # $out/libexec keeps `../lib/aeroftp` pointing at $out/lib/aeroftp.
      installPhase = ''
        runHook preInstall
        mkdir -p $out/lib $out/libexec $out/share
        cp -r usr/lib/aeroftp $out/lib/aeroftp
        cp usr/bin/aeroftp $out/libexec/aeroftp-dispatch
        cp -r usr/share/applications usr/share/icons usr/share/metainfo usr/share/mime $out/share/
        runHook postInstall
      '';

      # dontWrapGApps + explicit makeWrapper: the three names are the SAME
      # dispatcher distinguished only by argv[0] (`aftp`/`aeroftp-cli` route to the
      # CLI). wrapGAppsHook's automatic wrapper execs through a `.foo-wrapped`
      # path, which would erase argv[0] and turn every alias into the GUI.
      dontWrapGApps = true;
      postFixup = ''
        for name in aeroftp aeroftp-cli aftp; do
          makeWrapper $out/libexec/aeroftp-dispatch $out/bin/$name \
            --argv0 $name \
            "''${gappsWrapperArgs[@]}" \
            --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${pkgs.lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" (with pkgs.gst_all_1; [
          gstreamer
          gst-plugins-base
          gst-plugins-good
          gst-plugins-bad
          gst-libav
        ])}"
        done

        # The shipped .desktop entry points at the Debian path.
        substituteInPlace $out/share/applications/AeroFTP.desktop \
          --replace-fail "/usr/bin/aeroftp" "$out/bin/aeroftp"
      '';
    };
  in {
    environment.systemPackages = [aeroftp];
  };

  flake.featureMeta.aeroftp = {
    requires = ["desktop"];
    kind = "gui";
    # `aeroftp` is the GUI, `aeroftp-cli`/`aftp` the CLI faces of the dispatcher.
    provides.systemBins = ["aeroftp" "aeroftp-cli" "aftp"];
  };

  # feature test: per ADR 0002 a gui feature doesn't launch a window in the VM,
  # so the binaries landing on PATH is the whole assertion.
  flake.featureTests.aeroftp = {};
}
