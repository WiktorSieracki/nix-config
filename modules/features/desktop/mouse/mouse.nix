{
  # Logitech G502 HERO: the open-source "G Hub on Linux" setup.
  #
  # The G502's spare buttons are remapped (in onboard memory, via libratbag)
  # to unused function keys, which niri then binds to PipeWire mute scripts:
  #   thumb-back button (index 3) -> F13 -> mic-mute-toggle  (mute)
  #   profile button   (index 8) -> F14 -> deafen-toggle     (deafen)
  # Cursor speed lives in niri.nix (input.mouse.accel-speed).
  flake.modules.nixos.mouse = {pkgs, ...}: let
    micMute = pkgs.writeShellApplication {
      name = "mic-mute-toggle";
      runtimeInputs = [pkgs.wireplumber pkgs.libnotify pkgs.gnugrep];
      text = ''
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        if wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED; then
          notify-send -t 1200 -h string:x-canonical-private-synchronous:micmute "🎙️ Mic muted"
        else
          notify-send -t 1200 -h string:x-canonical-private-synchronous:micmute "🎙️ Mic live"
        fi
      '';
    };

    # "Deafen" = mute only Discord's audio output stream(s), so other apps
    # (Spotify, browser, games) keep playing.
    deafen = pkgs.writeShellApplication {
      name = "deafen-toggle";
      runtimeInputs = [pkgs.wireplumber pkgs.pipewire pkgs.libnotify pkgs.gnugrep pkgs.jq];
      text = ''
        mapfile -t ids < <(
          pw-dump | jq -r '
            .[]
            | select(.type=="PipeWire:Interface:Node")
            | select((.info.props["media.class"] // "")=="Stream/Output/Audio")
            | select(
                ((.info.props["application.name"]              // "") | ascii_downcase | test("discord"))
                or ((.info.props["node.name"]                 // "") | ascii_downcase | test("discord"))
                or ((.info.props["application.process.binary"] // "") | ascii_downcase | test("discord"))
                or ((.info.props["media.name"]                // "") | ascii_downcase | test("discord"))
              )
            | .id'
        )
        if [ "''${#ids[@]}" -eq 0 ]; then
          notify-send -t 1200 -h string:x-canonical-private-synchronous:deafen "🎧 Discord: no audio stream"
          exit 0
        fi
        if wpctl get-volume "''${ids[0]}" | grep -q MUTED; then
          target=0; msg="🔊 Discord undeafened"
        else
          target=1; msg="🔇 Discord deafened"
        fi
        for id in "''${ids[@]}"; do
          wpctl set-mute "$id" "$target"
        done
        notify-send -t 1200 -h string:x-canonical-private-synchronous:deafen "$msg"
      '';
    };

    # Re-apply the onboard button remap on boot. The mapping also persists in
    # the mouse's hardware, but this makes it reproducible (e.g. after a reset
    # or using the mouse on another machine).
    applyButtons = pkgs.writeShellApplication {
      name = "g502-apply-buttons";
      runtimeInputs = [pkgs.libratbag pkgs.gnugrep pkgs.coreutils];
      text = ''
        dev=""
        for _ in $(seq 1 30); do
          dev=$(ratbagctl list 2>/dev/null | grep -iF 'G502 HERO' | head -n1 | cut -d: -f1 || true)
          [ -n "$dev" ] && break
          sleep 2
        done
        if [ -z "$dev" ]; then
          echo "G502 not found; skipping button remap"
          exit 0
        fi
        # Use the clean profile 0 (profile 2 carried junk Ctrl+C/V macros and a
        # broken resolution table). Lock a calm DPI and a solid (non-cycling) LED
        # so the pointer speed and lighting can't drift.
        ratbagctl "$dev" profile active set 0
        ratbagctl "$dev" profile 0 dpi set 800
        ratbagctl "$dev" profile 0 led 0 set mode on
        ratbagctl "$dev" profile 0 led 1 set mode on
        # Top-left pair next to the left click (emit KEY_F13/F14 -> XF86Tools/XF86Launch5).
        ratbagctl "$dev" profile 0 button 7 action set key KEY_F13   # -> mute
        ratbagctl "$dev" profile 0 button 6 action set key KEY_F14   # -> deafen
        ratbagctl "$dev" profile 0 button 8 action set disabled      # disable profile-cycle (prevents profile/DPI drift)
      '';
    };
  in {
    # libratbag/ratbagd reprograms the mouse; piper is its GUI editor.
    services.ratbagd.enable = true;

    environment.systemPackages = [
      pkgs.piper
      pkgs.libratbag
      micMute
      deafen
      applyButtons
    ];

    systemd.services.g502-apply-buttons = {
      description = "Apply G502 onboard button remap (mute/deafen keys)";
      wantedBy = ["multi-user.target"];
      after = ["systemd-udev-settle.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${applyButtons}/bin/g502-apply-buttons";
      };
    };
  };

  # Remapped mouse keys -> mute scripts (scripts are on PATH via systemPackages).
  # NB: this xkb keymap maps the KEY_F13/KEY_F14 keycodes the mouse emits to the
  # XF86Tools / XF86Launch5 keysyms, so niri must bind *those* (verified via wev).
  flake.niriBinds.mouse = {...}: {
    "XF86Tools".spawn-sh = "mic-mute-toggle"; # button 7 (KEY_F13) -> mute
    "XF86Launch5".spawn-sh = "deafen-toggle"; # button 6 (KEY_F14) -> deafen
  };

  # No physical G502 in a VM (button remap is runtimeUntestable), but the helper
  # scripts and ratbagd are real and on PATH — that's what we assert.
  flake.featureMeta.mouse = {
    requires = [];
    kind = "service";
    runtimeUntestable = true;
  };

  flake.featureTests.mouse = {
    extraNixosModules = [
      ({lib, ...}: {
        # This oneshot polls 30×2s for the physical mouse before giving up; skip
        # it so multi-user.target isn't blocked ~60s in the VM.
        systemd.services.g502-apply-buttons.enable = lib.mkForce false;
      })
    ];
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v mic-mute-toggle")
      machine.succeed("command -v deafen-toggle")
      machine.succeed("command -v g502-apply-buttons")
      machine.succeed("systemctl cat ratbagd.service")
    '';
  };
}
