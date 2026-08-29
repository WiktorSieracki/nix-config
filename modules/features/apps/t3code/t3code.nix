{
  config,
  inputs,
  ...
}: let
  programs = config.flake.meta.programs;

  # nixpkgs ships the whole of upstream in one derivation: `bin/t3` (the Node
  # server + CLI) and `bin/t3code-desktop` (the Electron client). Only the
  # server half survives into either feature — see `t3CliFor` below.
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

  # `t3` on its own. On a host that runs the server, the bundled Electron client
  # is a trap: it never attaches to the running server, it forks a *second*
  # backend onto the same `~/.t3` database (notes.md). Dropping
  # `share/applications` is what keeps it out of the launcher; everything else
  # the package ships (icons, shell completions) is kept.
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

  # A chromeless window onto the local server, so t3code opens from the launcher
  # like an app rather than a browser tab. `--app` drops the tab strip and the
  # address bar. The dedicated `--user-data-dir` gives the window its own cookie
  # jar — so it stays paired with the server independently of the browsing
  # profile — and its own process, so it launches and closes on its own rather
  # than as a window of a running browser.
  #
  # `--class` is NOT set: chromium ignores it for `--app` windows on Wayland and
  # derives the app_id from the URL and the profile directory instead. Measured
  # with `niri msg -j windows`, this one comes up as `brave-localhost__-Default`,
  # which is what StartupWMClass below has to say. Re-check it with the same
  # command if the URL ever changes.
  t3codeWebFor = pkgs:
    pkgs.writeShellApplication {
      name = "t3code-web";
      runtimeInputs = [pkgs.${programs.chromium-browser}];
      text = ''
        exec ${programs.chromium-browser} \
          --app=http://localhost:3773 \
          --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/t3code-web" \
          "$@"
      '';
    };
in {
  flake.modules = {
    nixos = {
      # The client: a launcher entry, not an app. See notes.md.
      t3code = {pkgs, ...}: {
        environment.systemPackages = [(t3codeWebFor pkgs)];
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
          exec = "t3code-web";
          icon = "t3code"; # from the CLI package's share/icons, kept above
          terminal = false;
          categories = ["Development"];
          # The app_id chromium actually reports — see t3codeWebFor above.
          settings.StartupWMClass = "brave-localhost__-Default";
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
    # The entry points at http://localhost:3773, so the server has to be on this
    # host. A machine that only wants to *reach* another host's t3code needs no
    # feature at all — it opens the tailnet URL in a browser.
    requires = ["desktop" "t3code-server"];
    kind = "gui";
    provides.systemBins = ["t3code-web"];
  };

  # feature test: the chromeless window needs a live niri session and a paired
  # browser profile, so the launcher and its entry are as far as a headless VM
  # reaches. The entry can't be a `provides.userFiles` line: home-manager
  # installs `xdg.desktopEntries` as a *package* (home.packages), so under
  # `useUserPackages` it lands in the account's profile — a path that carries the
  # login and therefore can't be written as a static declaration.
  flake.featureTests.t3code = {
    testScript = ''
      entry = "/etc/profiles/per-user/tester/share/applications/t3code.desktop"
      machine.succeed(f"test -e {entry}")
      machine.succeed(f"grep -qx 'Exec=t3code-web' {entry}")
      machine.succeed(f"grep -qx 'StartupWMClass=brave-localhost__-Default' {entry}")
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
