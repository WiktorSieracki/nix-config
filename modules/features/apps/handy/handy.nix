{inputs, ...}: let
  pkgs = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  handy = pkgs.appimageTools.wrapType2 {
    pname = "handy";
    version = "0.7.6";
    src = pkgs.fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v0.7.6/Handy_0.7.6_amd64.AppImage";
      sha256 = "sha256-UZNt3lfKo6dBRWK1YD03HmcZsx/Zu2J3eD5VdTw+poU=";
    };
    extraRuntimeDependencies = [];
  };

  # Push-to-talk for `Mod+V`: handy toggles recording on SIGUSR2. Doing that
  # from a bare bind fails three ways -- niri's transient scope kills a
  # backgrounded handy, SIGUSR2 sent before the handler is installed kills it
  # instead of recording, and `pkill -x handy` also hits handy's helper
  # processes. See notes.md.
  handyToggle = pkgs.writeShellApplication {
    name = "handy-toggle";
    runtimeInputs = [pkgs.procps pkgs.gawk pkgs.coreutils pkgs.libnotify pkgs.systemd];
    text = ''
      # PID of the handy process that has installed a SIGUSR2 handler. SigCgt is
      # a 64-bit hex mask of caught signals; bit 11 (0-indexed) is signal 12,
      # SIGUSR2. Until that bit is set, SIGUSR2 still has its default action --
      # terminate -- so signalling early kills handy instead of recording.
      handy_pid() {
        local pid sigcgt
        while read -r pid; do
          [ -n "$pid" ] || continue
          sigcgt=$(awk '/^SigCgt:/{print $2}' "/proc/$pid/status" 2>/dev/null || true)
          [ -n "$sigcgt" ] || continue
          if ((0x$sigcgt & (1 << 11))); then
            printf '%s\n' "$pid"
            return 0
          fi
        done < <(pgrep -x handy || true)
        return 1
      }

      if ! pid=$(handy_pid); then
        # niri runs every bind inside a transient app-niri-*.scope and tears
        # that scope down the moment the bound command exits -- which would
        # take a backgrounded handy down with it. Give handy its own user unit
        # so it outlives this script. niri sets the display variables for the
        # processes it spawns, so forward them rather than trusting whatever
        # the user manager happened to import.
        if ! systemd-run --user --quiet --collect --unit=handy \
          --description="Handy speech-to-text" \
          --setenv=WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}" \
          --setenv=DISPLAY="''${DISPLAY:-}" \
          --setenv=XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-}" \
          --setenv=XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-}" \
          -- ${handy}/bin/handy --start-hidden --no-tray; then
          notify-send -t 3000 "Handy" "could not start handy.service"
          exit 1
        fi

        # Handler lands ~200 ms after a cold start; 10 s is a generous ceiling.
        # Bound by wall clock, not iteration count: each probe forks pgrep and
        # awk, so a fixed loop count drifts well past the stated timeout.
        deadline=$(($(date +%s) + 10))
        while [ "$(date +%s)" -lt "$deadline" ]; do
          sleep 0.05
          if pid=$(handy_pid); then break; fi
        done
      fi

      if [ -z "''${pid:-}" ]; then
        notify-send -t 3000 "Handy" "did not become ready within 10 s"
        exit 1
      fi

      kill -USR2 "$pid"
    '';
  };
in {
  flake.niriBinds.handy = {...}: {
    "Mod+V" = _: {
      props."hotkey-overlay-title" = "Handy: push-to-talk";
      content."spawn" = ["${handyToggle}/bin/handy-toggle"];
    };
  };

  flake.modules.homeManager.handy = {
    home.packages = [
      handy
      handyToggle
      pkgs.wtype
    ];
  };

  flake.featureMeta.handy = {
    requires = ["desktop"];
    kind = "gui";
    # AppImage wrapped via appimageTools; binary is `handy`, in the HM profile.
    # `handy-toggle` drives it from the niri bind.
    provides.userBins = ["handy" "handy-toggle"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.handy = {};
}
