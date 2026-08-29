{inputs, ...}: let
  # One package, two features. Upstream ships the desktop client and the
  # headless server from the same tree, and so does nixpkgs: `bin/t3code-desktop`
  # (Electron) and `bin/t3` (the Node server + CLI). The override therefore
  # lives here rather than inside either module.
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
in {
  flake.modules = {
    nixos = {
      # The client: the Electron app, plus the `t3` CLI for one-off servers.
      t3code = {pkgs, ...}: {
        environment.systemPackages = [(t3codeFor pkgs)];
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

    # The server: `t3 serve`, published on the tailnet, per account.
    homeManager.t3code-server = {
      pkgs,
      lib,
      ...
    }: let
      t3code = t3codeFor pkgs;
    in {
      # Self-sufficient by design (ADR 0002): this feature does not `requires`
      # t3code, because a headless host runs the server without any GUI. On a
      # host that enables both, this is the same store path twice.
      home.packages = [t3code];

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
          ExecStart = "${lib.getExe' t3code "t3"} serve --host 127.0.0.1 --port 3773 --no-browser --tailscale-serve";
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

  flake.featureMeta.t3code = {
    requires = ["desktop"];
    kind = "gui";
    provides = {
      # nixpkgs' mainProgram is t3code-desktop; `t3` is the server/CLI entrypoint.
      systemBins = ["t3code-desktop" "t3"];
      files = ["/run/current-system/sw/share/applications/t3code.desktop"];
    };
  };

  # feature test: GUI app — per ADR 0002 assert the binaries land on PATH and the
  # desktop entry is installed (via `provides`), rather than launching a window.
  flake.featureTests.t3code = {};

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
