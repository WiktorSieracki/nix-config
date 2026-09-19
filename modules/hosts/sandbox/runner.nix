{
  # `sandbox` — the host-side driver for the live sandbox (Tier-1-live).
  #
  # Deliberately thin and feature-blind: it knows how to boot one throwaway VM,
  # push a generation into it, copy a script in and pictures out. Everything
  # about *what* a feature should do lives in that feature's `check.sh`;
  # everything about *how* a VM is assembled lives in default.nix next door.
  #
  # A package, not a feature: `flake.modules.*` names are audited by
  # feature-coverage, `packages.*` are not — and this is agent tooling for the
  # repo, not something a host installs.
  perSystem = {pkgs, ...}: {
    packages.sandbox = pkgs.writeShellApplication {
      name = "sandbox";
      runtimeInputs = with pkgs; [
        coreutils
        findutils
        git
        gnugrep
        jq
        nix
        nixos-rebuild
        openssh
        procps
        socat
        systemd
        util-linux
      ];
      text = ''
        set -euo pipefail

        state="''${XDG_RUNTIME_DIR:-/tmp}/nix-sandbox"
        flake="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")"
        port=2222
        unit=nix-sandbox-vm
        # Guest RAM is 3G (modules/hosts/sandbox/default.nix); the rest is
        # QEMU's own device model and the virgl renderer.
        mem_max=4500M
        # scp spells the port -P, ssh spells it -p — sharing one array silently
        # turns the port number into a filename argument.
        ssh_common=(-o StrictHostKeyChecking=no
          -o UserKnownHostsFile=/dev/null
          -o LogLevel=ERROR
          -o ConnectTimeout=5)
        ssh_opts=(-p "$port" "''${ssh_common[@]}")
        scp_opts=(-P "$port" "''${ssh_common[@]}")

        die() { echo "sandbox: $*" >&2; exit 1; }

        # ── state ────────────────────────────────────────────────────────────
        feature_of() {
          [ -f "$state/feature" ] || die "no sandbox is running — start one with: sandbox up <feature>"
          cat "$state/feature"
        }
        artifacts() {
          d="/tmp/sandbox/$(feature_of)"
          mkdir -p "$d"
          echo "$d"
        }

        # ── guest access ─────────────────────────────────────────────────────
        # Every guest command goes through sandbox-env, which resolves the
        # session's wayland/niri/ydotool sockets inside the guest (an ssh
        # command otherwise arrives with an empty environment and every probe
        # tool fails for a reason that has nothing to do with the feature).
        # ssh joins its arguments with spaces and hands the result to the
        # remote *shell*, so any quoting the local shell already consumed is
        # gone: `guest sh -c 'test -n "$VAR" && cmd'` arrives unquoted, $VAR
        # expands in the login shell (empty) and the `&&` half runs outside
        # sandbox-env entirely. Re-quoting each argument with %q makes the
        # remote shell reconstruct exactly the words we passed.
        # shellcheck disable=SC2029 # the re-quoted command is meant to expand there
        guest() { ssh "''${ssh_opts[@]}" tester@127.0.0.1 "sandbox-env $(printf '%q ' "$@")"; }
        # shellcheck disable=SC2029 # ditto
        guest_root() { ssh "''${ssh_opts[@]}" root@127.0.0.1 "$(printf '%q ' "$@")"; }

        wait_for_ssh() {
          for _ in $(seq 1 120); do
            # A dead VM will never answer, so stop waiting the moment the unit
            # gives up — and show why, instead of a timeout two minutes later
            # that says nothing about the cause.
            if ! systemctl --user --quiet is-active "$unit"; then
              journalctl --user -u "$unit" --no-pager -n 15 >&2
              die "the VM exited before it came up (see the log above)"
            fi
            if ssh "''${ssh_opts[@]}" -o BatchMode=yes root@127.0.0.1 true 2>/dev/null; then
              return 0
            fi
            sleep 1
          done
          die "guest never answered on ssh — see: journalctl --user -u $unit"
        }

        wait_for_session() {
          # No shell on the far side: sandbox-env resolves the socket and execs
          # niri directly, which fails on its own if the session is not there.
          # Under software GL a session can take a couple of minutes to settle.
          for _ in $(seq 1 180); do
            if guest niri msg version >/dev/null 2>&1; then
              return 0
            fi
            sleep 1
          done
          die "the graphical session never came up — see: journalctl --user -u $unit"
        }

        # ── QMP (the pre-login fallback) ─────────────────────────────────────
        # Only for what happens before a session and sshd exist: GRUB, boot,
        # the SDDM greeter. Note screendump does not capture the hardware
        # cursor plane — anything about the pointer must go through grim.
        qmp() {
          [ -S "$state/qmp.sock" ] || die "no QMP socket — is a sandbox running?"
          printf '%s\n' '{"execute":"qmp_capabilities"}' "$1" \
            | socat - "UNIX-CONNECT:$state/qmp.sock"
        }

        cmd="''${1:-}"
        [ -n "$cmd" ] || die "usage: sandbox {up|status|logs|red|check|deploy|shot|exec|key|screendump|down}"
        shift || true

        case "$cmd" in
          # ── up <feature> ───────────────────────────────────────────────────
          # Boots the RED state: base infrastructure, feature absent.
          up)
            feature="''${1:-}"
            [ -n "$feature" ] || die "usage: sandbox up <feature>"
            ! systemctl --user --quiet is-active "$unit" \
              || die "a sandbox is already running ($(cat "$state/feature")) — sandbox down first"

            meta="$(nix eval --json "$flake#featureMeta.$feature" 2>/dev/null)" \
              || die "'$feature' is not a known feature (no featureMeta)"
            if [ "$(jq -r '.runtimeUntestable' <<<"$meta")" = "true" ]; then
              die "'$feature' is runtimeUntestable — its runtime cannot be reached from a VM (no hardware / no real secrets). A sandbox run could only ever produce a false 'it works'."
            fi
            case "$feature" in
              desktop | niri)
                die "'$feature' is the sandbox's own infrastructure — the base VM already runs it, so there is no red state to start from. Its runtime is exercised by every other sandbox run."
                ;;
            esac

            # QEMU's user-net forward is the only way in, and it fails softly:
            # the VM boots, nothing listens, and every later step reports a
            # timeout that looks like a broken guest. Anything already on the
            # port (a leftover QEMU, an ssh tunnel) has to be named here.
            if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
              exec 3>&-
              die "something is already listening on 127.0.0.1:$port — a stale sandbox QEMU? Check: ss -ltnp | grep $port"
            fi

            # A previous `up` that died mid-build leaves a state dir behind;
            # nothing in it survives a boot anyway.
            rm -rf "$state"
            mkdir -p "$state"
            echo "$feature" > "$state/feature"

            echo "sandbox: building the base VM…"
            vm="$(nix build --no-link --print-out-paths \
              "$flake#nixosConfigurations.sandbox-base.config.system.build.vm")"
            vm_bin="$(echo "$vm"/bin/run-*-vm)"

            # Ephemeral overlay: every sandbox starts clean, like the `vm` host.
            rm -f "$state/disk.qcow2"

            # The VM runs as its own transient systemd unit, NOT as a child of
            # whoever typed the command. Two reasons, both learned the hard way:
            # a child of the agent's terminal dies with the agent's session, and
            # — worse — it shares that session's cgroup, so a hungry guest gets
            # the editor's backend OOM-killed instead of itself. MemoryMax caps
            # the whole QEMU process (guest RAM + device model + virgl) so the
            # sandbox can never take the desktop down with it.
            #
            # SDL on wayland so Ctrl+Alt+G can grab into the guest if a human
            # wants to poke it; the app_id/title is what the niri window rule
            # matches to park this window on the right monitor.
            systemd-run --user --quiet \
              --unit="$unit" \
              --description="nix-config live sandbox VM ($feature)" \
              --property=MemoryMax="$mem_max" \
              --property=MemorySwapMax=0 \
              --setenv=NIX_DISK_IMAGE="$state/disk.qcow2" \
              --setenv=SDL_VIDEODRIVER=wayland \
              --setenv=SDL_VIDEO_WAYLAND_WMCLASS=nix-sandbox \
              --setenv=WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-}" \
              --setenv=XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-}" \
              --setenv=QEMU_OPTS="-display sdl,gl=on -qmp unix:$state/qmp.sock,server=on,wait=off" \
              -- "$vm_bin"

            wait_for_ssh
            wait_for_session
            echo "sandbox: up — feature '$feature' is NOT installed yet (red state), ssh on port $port"
            ;;

          # ── status ─────────────────────────────────────────────────────────
          status)
            if systemctl --user --quiet is-active "$unit"; then
              echo "running: $(cat "$state/feature") (unit $unit, ssh port $port)"
              systemctl --user show "$unit" -p MemoryCurrent -p MemoryMax --value | tr '\n' ' '
              echo
              guest_root readlink -f /run/current-system || true
            else
              echo "not running"
            fi
            ;;

          # ── logs ───────────────────────────────────────────────────────────
          logs)
            journalctl --user -u "$unit" --no-pager -n "''${1:-80}"
            ;;

          # ── red <feature> / check <feature> ────────────────────────────────
          # `red` is the TDD gate made executable: the same check, but passing
          # means failure. A check that is already green on the base measures
          # nothing, and every later green would be meaningless.
          red | check)
            feature="''${1:-$(feature_of)}"
            script="$(find "$flake/modules/features" \
              \( -path "*/$feature/check.sh" -o -name "$feature.check.sh" \) -type f | head -n1)"
            [ -n "$script" ] || die "no check script for '$feature' — expected modules/features/**/$feature/check.sh or $feature.check.sh"

            scp "''${scp_opts[@]}" -q "$script" "tester@127.0.0.1:/tmp/check-$feature.sh"
            set +e
            guest sh "/tmp/check-$feature.sh"
            rc=$?
            set -e

            if [ "$cmd" = "red" ]; then
              if [ "$rc" -eq 0 ]; then
                die "VACUOUS CHECK: $script passes on the base system, where '$feature' is not installed. It is asserting something that is true anyway — rewrite it before going green."
              fi
              echo "sandbox: red confirmed (check fails without the feature, exit $rc)"
            else
              exit "$rc"
            fi
            ;;

          # ── deploy <feature> ───────────────────────────────────────────────
          # Installs the feature into the RUNNING VM — no reboot. The session
          # restart is not optional: after a switch the running niri still holds
          # the previous generation's config (its wrapper pins NIRI_CONFIG to a
          # store path) and noctalia still runs from the path it was spawned
          # with, so a new keybind would "not work" for reasons that have
          # nothing to do with the feature.
          deploy)
            feature="''${1:-$(feature_of)}"
            echo "sandbox: building and switching to sandbox-$feature…"
            NIX_SSHOPTS="''${ssh_opts[*]}" \
              nixos-rebuild switch \
                --flake "$flake#sandbox-$feature" \
                --target-host root@127.0.0.1

            echo "sandbox: restarting the graphical session so it matches the new generation…"
            guest_root systemctl restart display-manager
            wait_for_session
            echo "sandbox: deployed — '$feature' is now installed (green state expected)"
            ;;

          # ── shot <label> ───────────────────────────────────────────────────
          shot)
            label="''${1:-shot}"
            dir="$(artifacts)"
            n="$(printf '%02d' "$(find "$dir" -name '*.png' | wc -l)")"
            out="$dir/$n-$label.png"
            guest grim /tmp/shot.png
            scp "''${scp_opts[@]}" -q "tester@127.0.0.1:/tmp/shot.png" "$out"
            echo "$out"
            ;;

          # ── exec -- <cmd…> ─────────────────────────────────────────────────
          # The escape hatch: niri msg, ydotool, journalctl, anything. The
          # runner does not try to wrap every way a feature can be used.
          exec)
            if [ "''${1:-}" = "--" ]; then shift; fi
            if [ "''${1:-}" = "--root" ]; then
              shift
              guest_root "$@"
            else
              guest "$@"
            fi
            ;;

          # ── key / screendump (pre-login only) ──────────────────────────────
          key)
            [ $# -gt 0 ] || die "usage: sandbox key <qemu-key> [qemu-key…]"
            for k in "$@"; do
              qmp "{\"execute\":\"send-key\",\"arguments\":{\"keys\":[{\"type\":\"qcode\",\"data\":\"$k\"}]}}" >/dev/null
            done
            ;;

          screendump)
            out="''${1:-$(artifacts)/qmp-screendump.png}"
            qmp "{\"execute\":\"screendump\",\"arguments\":{\"filename\":\"$out\",\"format\":\"png\"}}" >/dev/null
            echo "$out"
            ;;

          # ── down ───────────────────────────────────────────────────────────
          down)
            systemctl --user stop "$unit" 2>/dev/null || true
            rm -rf "$state"
            echo "sandbox: down (screenshots kept under /tmp/sandbox/)"
            ;;

          *) die "unknown command '$cmd'" ;;
        esac
      '';
    };
  };
}
