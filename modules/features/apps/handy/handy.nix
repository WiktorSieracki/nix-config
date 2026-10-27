let
  # Push-to-talk for `Mod+V`: `handy --toggle-transcription` forwards the toggle
  # to the running instance. Doing that from a bare bind fails two ways --
  # with no instance running the flag starts a whole app inside niri's
  # transient scope (which dies with the bind), and a toggle sent while handy
  # is still starting is dropped ("TranscriptionCoordinator not initialized").
  # See notes.md.
  mkHandyToggle = pkgs:
    pkgs.writeShellApplication {
      name = "handy-toggle";
      runtimeInputs = [pkgs.gawk pkgs.coreutils pkgs.libnotify pkgs.systemd];
      text = ''
        handy=${pkgs.handy}/bin/handy

        # True once handy.service's main process has installed its SIGUSR2
        # handler, which handy does right after initializing the coordinator
        # that toggles act on -- so it doubles as "ready for a toggle". SigCgt
        # is a 64-bit hex mask of caught signals; bit 11 (0-indexed) is signal
        # 12, SIGUSR2. The PID comes from the unit, not pgrep: nixpkgs' wrapper
        # names the process `.handy-wrapped`.
        ready() {
          local pid sigcgt
          pid=$(systemctl --user show --property=MainPID --value handy.service 2>/dev/null || true)
          [ -n "$pid" ] && [ "$pid" != 0 ] || return 1
          sigcgt=$(awk '/^SigCgt:/{print $2}' "/proc/$pid/status" 2>/dev/null || true)
          [ -n "$sigcgt" ] && ((0x$sigcgt & (1 << 11)))
        }

        if ! ready; then
          # niri runs every bind inside a transient app-niri-*.scope and tears
          # that scope down the moment the bound command exits -- which would
          # take a backgrounded handy down with it. Give handy its own user unit
          # so it outlives this script. niri sets the display variables for the
          # processes it spawns, so forward them rather than trusting whatever
          # the user manager happened to import. An already active unit is one
          # still starting up: just wait for it.
          if ! systemctl --user is-active --quiet handy.service \
            && ! systemd-run --user --quiet --collect --unit=handy \
              --description="Handy speech-to-text" \
              --setenv=WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}" \
              --setenv=DISPLAY="''${DISPLAY:-}" \
              --setenv=XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-}" \
              --setenv=XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-}" \
              -- "$handy" --start-hidden --no-tray; then
            notify-send -t 3000 "Handy" "could not start handy.service"
            exit 1
          fi

          # Ready ~1 s after a cold start; 10 s is a generous ceiling. Bound by
          # wall clock, not iteration count: each probe forks systemctl and awk.
          deadline=$(($(date +%s) + 10))
          until ready; do
            if [ "$(date +%s)" -ge "$deadline" ]; then
              notify-send -t 3000 "Handy" "did not become ready within 10 s"
              exit 1
            fi
            sleep 0.05
          done
        fi

        exec "$handy" --toggle-transcription
      '';
    };
in {
  flake.niriBinds.handy = {pkgs, ...}: {
    "Mod+V" = _: {
      props."hotkey-overlay-title" = "Handy: push-to-talk";
      content."spawn" = ["${mkHandyToggle pkgs}/bin/handy-toggle"];
    };
  };

  flake.modules.homeManager.handy = {pkgs, ...}: {
    home.packages = [
      pkgs.handy
      (mkHandyToggle pkgs)
      pkgs.wtype
    ];
  };

  flake.featureMeta.handy = {
    requires = ["desktop"];
    kind = "gui";
    # nixpkgs' handy; binary is `handy`, in the HM profile.
    # `handy-toggle` drives it from the niri bind.
    provides.userBins = ["handy" "handy-toggle"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.handy = {};
}
