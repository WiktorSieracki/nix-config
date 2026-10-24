let
  mkPokexgames = pkgs: let
    # PokeXGames ships one unversioned zip (Windows + Linux client side by side).
    # It is only the bootstrap: on first start the client downloads its own
    # updates into the directory it runs from — see notes.md.
    src = pkgs.fetchurl {
      url = "https://download.pokexgames.com/pxg-linux.zip";
      hash = "sha256-Qi8WnH+tPhOoAFT9knoYhi9YoHG2l6AIb1kjT1jB8yo=";
    };

    icon = pkgs.runCommand "pokexgames-icon" {nativeBuildInputs = [pkgs.unzip];} ''
      unzip -qj ${src} assets/pxgmeclient.png
      install -Dm644 pxgmeclient.png $out/share/pixmaps/pokexgames.png
    '';

    desktopItem = pkgs.makeDesktopItem {
      name = "pokexgames";
      desktopName = "PokeXGames";
      exec = "pokexgames";
      icon = "pokexgames";
      categories = ["Game"];
    };

    # The client patches itself in place, so it can't run from the read-only
    # store: unpack it once into a writable per-user dir and run it from there.
    launcher = pkgs.writeShellScript "pokexgames-launcher" ''
      set -eu
      dir="''${XDG_DATA_HOME:-$HOME/.local/share}/pokexgames"
      if [ ! -e "$dir/pxgme-linux" ]; then
        mkdir -p "$dir"
        ${pkgs.unzip}/bin/unzip -qo ${src} -d "$dir"
        chmod +x "$dir/pxgme-linux"
      fi
      cd "$dir"
      exec ./pxgme-linux "$@"
    '';
  in
    # A prebuilt glibc binary that only links fontconfig and dlopens the rest
    # (SDL: GL/EGL/Vulkan, X11/Wayland, Pulse/ALSA) from the standard paths —
    # an FHS env serves those without patching the self-updating binary.
    pkgs.buildFHSEnv {
      name = "pokexgames";
      runScript = launcher;
      targetPkgs = p:
        with p; [
          fontconfig
          freetype
          libGL
          libglvnd
          vulkan-loader
          libx11
          libxext
          libxcursor
          libxfixes
          libxi
          libxrandr
          libxscrnsaver
          libxcb
          libxkbcommon
          wayland
          alsa-lib
          libpulseaudio
          dbus
          udev
        ];
      extraInstallCommands = ''
        install -Dm644 ${desktopItem}/share/applications/pokexgames.desktop \
          $out/share/applications/pokexgames.desktop
        install -Dm644 ${icon}/share/pixmaps/pokexgames.png \
          $out/share/pixmaps/pokexgames.png
      '';
    };
in {
  flake.modules.nixos.pokexgames = {pkgs, ...}: {
    environment.systemPackages = [(mkPokexgames pkgs)];
  };

  flake.featureMeta.pokexgames = {
    requires = ["desktop"];
    kind = "gui";
    provides.systemBins = ["pokexgames"];
  };

  # feature test: a gui feature doesn't open a window in the VM, but the
  # bootstrap half of the launcher runs headless — it must unpack the client
  # into the writable data dir before SDL gives up on the missing display.
  flake.featureTests.pokexgames = {
    testScript = ''
      machine.execute("timeout 30 pokexgames")
      machine.succeed("test -x /root/.local/share/pokexgames/pxgme-linux")
      machine.succeed("test -f /root/.local/share/pokexgames/assets/init.klua")
    '';
  };
}
