{
  flake.modules.nixos.t3code = {pkgs, ...}: let
    pname = "t3code";
    version = "0.0.31";

    src = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-AqTkoSKeQwmql3L9F5SbD1XyqeFyqe11ciq9Tp04Zyw=";
    };

    # Upstream ships *only* an AppImage for Linux (no .deb/.rpm), so unlike
    # orca we have to unpack it ourselves. Inside it is the same plain
    # electron-builder tree, which `autoPatchelfHook` then links against
    # nixpkgs' own libs — we do not run the AppImage through `wrapType2`,
    # whose FHS sandbox hides `/run/opengl-driver` from the GPU process.
    # See notes.md.
    appimageContents = pkgs.appimageTools.extract {inherit pname version src;};

    t3code = pkgs.stdenv.mkDerivation {
      inherit pname version src;

      nativeBuildInputs = with pkgs; [
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

      # Same ANGLE trap as orca: the bundled `libEGL.so` dlopens the *native*
      # `libEGL.so.1`, and `dlopen` resolves against the runpath of the calling
      # library, so libglvnd must be on every patched ELF — not just the main
      # binary (`runtimeDependencies` would miss it).
      appendRunpaths = [(pkgs.lib.makeLibraryPath [pkgs.libglvnd])];

      # The bundled chrome-sandbox is setuid-only; on NixOS Electron falls back
      # to kernel user namespaces instead.
      dontWrapGApps = true;

      unpackPhase = ''
        cp -r ${appimageContents} ./app
        chmod -R u+w ./app
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p $out/share
        cp -r app $out/share/t3code
        cp -r app/usr/share/icons $out/share/icons
        # AppImage scaffolding: `usr/lib` is a stack of ancient distro shims and
        # the two icon symlinks only point into `usr/share`.
        rm -rf $out/share/t3code/usr
        rm -f $out/share/t3code/t3code.png $out/share/t3code/.DirIcon

        install -Dm644 app/t3code.desktop $out/share/applications/t3code.desktop
        substituteInPlace $out/share/applications/t3code.desktop \
          --replace-fail "Exec=AppRun" "Exec=t3code"

        runHook postInstall
      '';

      # `AppRun` only exists to bootstrap the AppImage mount; the real
      # entrypoint is the `t3code` binary next to it.
      postFixup = ''
        rm -f $out/share/t3code/AppRun
        makeWrapper $out/share/t3code/t3code $out/bin/t3code \
          "''${gappsWrapperArgs[@]}"
      '';

      meta = {
        description = "Agent harness control surface for Claude Code, Codex, Cursor and friends";
        homepage = "https://github.com/pingdotgg/t3code";
        license = pkgs.lib.licenses.mit;
        platforms = ["x86_64-linux"];
        mainProgram = "t3code";
      };
    };
  in {
    environment.systemPackages = [t3code];
  };

  flake.featureMeta.t3code = {
    requires = ["desktop"];
    kind = "gui";
    provides = {
      systemBins = ["t3code"];
      files = ["/run/current-system/sw/share/applications/t3code.desktop"];
    };
  };

  # feature test: GUI app — per ADR 0002 assert the binary lands on PATH and the
  # desktop entry is installed (via `provides`), rather than launching a window.
  flake.featureTests.t3code = {};
}
