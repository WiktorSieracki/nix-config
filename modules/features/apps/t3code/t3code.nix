{inputs, ...}: let
  # nixpkgs ships the whole of upstream in one derivation: `bin/t3` (the Node
  # server + CLI) and `bin/t3code-desktop` (the Electron client). Each feature
  # takes one half — `t3CliFor` for the server, `t3codeAppFor` for the client —
  # and neither takes the package as-is.
  #
  # nixpkgs wraps every t3code binary with a PATH prefix of the agents it should
  # drive. We swap nixpkgs' claude-code for the llm-agents one so t3code runs the
  # exact same `claude` the `claude-code` feature puts on PATH, and drop codex
  # (nixpkgs enables it by default) — no account here is logged into it. t3code
  # finds a provider by binary name, so `claude` on PATH is the whole contract;
  # see notes.md.
  t3codeFor = pkgs:
    pkgs.t3code.override {
      enableClaude = true;
      claude-code = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code;
      enableCodex = false;
    };

  # `t3` on its own. Upstream's own desktop entry is the trap: it runs
  # `t3code-desktop` bare, and a bare app forks a second backend onto the unit's
  # own `~/.t3` database, where the two servers' projections drift (notes.md).
  # Dropping `share/applications` is what keeps that entry out of the launcher,
  # leaving `t3codeAppFor`'s wrapper — which isolates the app's backend — as the
  # only way in. Everything else the package ships (icons, shell completions) is
  # kept; the launcher entry below takes its icon from here.
  t3CliFor = pkgs: let
    full = t3codeFor pkgs;
  in
    pkgs.runCommand "t3-${full.version}" {
      meta.mainProgram = "t3";
      passthru.full = full;
    } ''
      mkdir -p "$out/bin" "$out/share"
      ln -s ${full}/bin/t3 "$out/bin/t3"
      for dir in ${full}/share/*; do
        if [ "$(basename "$dir")" != applications ]; then
          ln -s "$dir" "$out/share/"
        fi
      done
    '';

  # The client: the Electron app, kept off the unit's data by construction.
  # The app *always* spawns its own backend — `DesktopConfig` has no "attach to
  # a running server" option (checked upstream) — so `T3CODE_HOME` gives that
  # backend a data directory of its own and `T3CODE_PORT` a port of its own,
  # and the unit's `~/.t3/userdata/state.sqlite` is never opened twice. That
  # second backend does nothing but serve the app's UI; the real server is
  # reached by pairing the unit as a saved environment, once, in
  # Settings → Connections. See notes.md for the recipe and what it buys
  # (the preview panel and the agent's `preview_*` tools, which no browser
  # client can have).
  #
  # `--ozone-platform=wayland` is passed explicitly instead of the NIXOS_OZONE_WL
  # dance in `discord.nix`: nixpkgs' t3code wrapper only prefixes PATH, so it acts
  # on no such variable. Electron's own `--ozone-platform-hint=auto` reads the
  # session environment and was measured falling back to X11 (dying on
  # `Missing X server or $DISPLAY`) when `XDG_SESSION_TYPE` was unset, which a
  # launcher entry cannot guarantee. The explicit flag needs no session state.
  t3codeAppFor = pkgs: let
    full = t3codeFor pkgs;
  in
    pkgs.writeShellApplication {
      name = "t3code-desktop";
      text = ''
        export T3CODE_HOME="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code-desktop"
        export T3CODE_PORT=3799
        exec ${full}/bin/t3code-desktop --ozone-platform=wayland "$@"
      '';
    };
in {
  flake.modules = {
    nixos = {
      # The client. See notes.md.
      t3code = {pkgs, ...}: {
        environment.systemPackages = [(t3codeAppFor pkgs)];
      };

      # Without lingering, a user service only exists between login and logout —
      # which defeats the point of reaching this machine from a phone. `hostUsers`
      # is the loader's account → features map, so only the accounts that actually
      # enable this feature get it.
      t3code-server = {
        lib,
        hostUsers ? {},
        ...
      }: {
        users.users =
          lib.genAttrs
          (lib.filter (u: builtins.elem "t3code-server" hostUsers.${u}) (builtins.attrNames hostUsers))
          (_: {linger = true;});
      };
    };

    homeManager = {
      t3code = {...}: {
        xdg.desktopEntries.t3code = {
          name = "T3 Code";
          exec = "t3code-desktop";
          icon = "t3code"; # from the CLI package's share/icons, kept above
          terminal = false;
          categories = ["Development"];
          # The app_id the Electron app reports, measured on 2026-09-05 with
          # `niri msg -j windows`. Re-measure with the same command after a
          # major t3code bump.
          settings.StartupWMClass = "t3code";
        };
      };

      # The server: `t3 serve`, published on the tailnet, per account.
      t3code-server = {
        pkgs,
        lib,
        ...
      }: let
        t3 = t3CliFor pkgs;
      in {
        home.packages = [t3];

        systemd.user.services.t3code = {
          Unit.Description = "T3 Code server, published on the tailnet over Tailscale Serve";

          Service = {
            # `serve` = start headless and print the pairing token, URL and QR code
            # (they land in the journal; `t3 pair` mints a fresh one on demand).
            # `--tailscale-serve` makes Tailscale Serve terminate HTTPS on the
            # MagicDNS name and proxy to this backend, which is why the listener
            # stays on loopback and no firewall port is opened. HTTPS is what lets
            # the phone use https://app.t3.codes — browsers block an HTTPS page
            # from opening a plain ws:// backend.
            ExecStart = "${lib.getExe t3} serve --host 127.0.0.1 --port 3773 --no-browser --tailscale-serve";
            WorkingDirectory = "%h";
            # tailscaled is a *system* unit, so a user unit cannot order against it.
            # `tailscale serve` fails until the tailnet is up, so retry instead.
            Restart = "on-failure";
            RestartSec = 10;
          };

          Install.WantedBy = ["default.target"];
        };
      };
    };
  };

  flake.featureMeta.t3code = {
    # The app is paired to *this* host's unit, and takes its icon from the CLI
    # package `t3code-server` installs, so the server belongs on the same host.
    # A machine that only wants to *reach* another host's t3code needs no
    # feature at all — it opens the tailnet URL in a browser (and gets no
    # preview there; notes.md).
    requires = ["desktop" "t3code-server"];
    kind = "gui";
    provides.systemBins = ["t3code-desktop"];
  };

  # feature test: the app needs a live niri session and a paired environment, so
  # the launcher entry and the wrapper's contract are as far as a headless VM
  # reaches. The entry can't be a `provides.userFiles` line: home-manager
  # installs `xdg.desktopEntries` as a *package* (home.packages), so under
  # `useUserPackages` it lands in the account's profile — a path that carries the
  # login and therefore can't be written as a static declaration.
  flake.featureTests.t3code = {
    testScript = ''
      entry = "/etc/profiles/per-user/tester/share/applications/t3code.desktop"
      machine.succeed(f"test -e {entry}")
      machine.succeed(f"grep -qx 'Exec=t3code-desktop' {entry}")
      machine.succeed(f"grep -qx 'StartupWMClass=t3code' {entry}")

      # The two variables that keep the app's own backend off the unit's
      # database and port, and the flag without which it dies on a Wayland-only
      # session. Losing any of them is silent at eval time.
      wrapper = machine.succeed("command -v t3code-desktop").strip()
      machine.succeed(f"grep -q 'T3CODE_HOME=' {wrapper}")
      machine.succeed(f"grep -q 'T3CODE_PORT=3799' {wrapper}")
      machine.succeed(f"grep -q -- '--ozone-platform=wayland' {wrapper}")
    '';
  };

  flake.featureMeta.t3code-server = {
    requires = ["tailscale"];
    kind = "service";
    # The unit's whole job is to publish itself on a tailnet. A VM has no tailnet
    # to join, so `tailscale serve` — and with it the service — cannot come up;
    # the feature test guards eval, the unit being installed, and the CLI.
    runtimeUntestable = true;
    provides = {
      userBins = ["t3"];
      userFiles = [".config/systemd/user/t3code.service"];
    };
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.t3code-server = {};
}
