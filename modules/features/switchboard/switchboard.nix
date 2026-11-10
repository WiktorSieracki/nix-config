{
  flake.modules.nixos.switchboard = {pkgs, ...}: {
    environment.systemPackages = [
      # A Go program whose sources live in this feature's folder
      # (self-sufficiency): a bubbletea TUI, and `switchboard web` — the same
      # feature lists in a browser, served on loopback from the files embedded
      # in the binary (web/). buildGoModule vendors the deps from go.sum and
      # also runs `go test ./...` in its checkPhase, so the unit tests (the
      # rules, the HTTP API and who it answers to) gate every build.
      (pkgs.buildGoModule {
        pname = "switchboard";
        version = "0.3.0";
        src = ./.;
        vendorHash = "sha256-4rK69s1uTFBV20endymLw6JEUfrh51bznZEgbujUQls=";

        nativeBuildInputs = [pkgs.copyDesktopItems];

        # gitops_test.go and web_test.go drive real `git` in a throwaway
        # repository.
        nativeCheckInputs = [pkgs.git];

        # Launcher entry for the web UI. It needs no terminal: the server
        # opens the browser itself and exits once no page has asked it for
        # anything in a while (see `--idle-timeout`).
        desktopItems = [
          (pkgs.makeDesktopItem {
            name = "switchboard";
            desktopName = "Switchboard";
            comment = "Switch this nix-config's features on and off, per host";
            exec = "switchboard web";
            icon = "preferences-system";
            categories = ["Settings" "System"];
            keywords = ["nixos" "features" "nix-config"];
          })
        ];

        # `sb` shorthand. A symlink in the derivation rather than a shell
        # alias: it works from any shell (and from scripts/exec), and the
        # feature test asserts it via `provides.systemBins`.
        postInstall = "ln -s switchboard $out/bin/sb";

        meta.mainProgram = "switchboard";
      })
    ];
  };

  # Switchboard drives `nix eval`/`nix build` itself (ambient in core), but its
  # finale shells out to `nh os test/switch` — provided by the `nix` feature.
  # The web UI opens in whatever browser the host has; without one (or without
  # a session) `switchboard web --no-open` still serves, so neither a browser
  # nor `desktop` is a requirement.
  flake.featureMeta.switchboard = {
    requires = ["nix"];
    kind = "cli";
    provides = {
      systemBins = ["switchboard" "sb"];
      files = ["/run/current-system/sw/share/applications/switchboard.desktop"];
    };
  };

  # feature test (kind cli): the binary is on PATH and handles --version/--help
  # headless (no TTY) with exit 0 — the TUI itself needs a real terminal. The
  # web UI needs none, so it is exercised for real: served, read through its
  # API, and refused where it must refuse.
  # The `requires` closure pulls in `nix`, whose nixpkgs.config.allowUnfree
  # collides with nixosTest's read-only nixpkgs — force-override it, same
  # stub as the nix feature's own feature test.
  flake.featureTests.switchboard = {
    extraNixosModules = [
      ({lib, ...}: {nixpkgs.config = lib.mkForce {allowUnfree = true;};})
    ];
    testScript = ''
      machine.succeed("switchboard --version")
      machine.succeed("switchboard --help")
      machine.succeed("switchboard web --help")
      # the `sb` shorthand resolves to the same program
      machine.succeed("sb --version")

      # `switchboard web` over a stand-in repo with one host. The VM has no
      # flake to evaluate the feature catalog from; the server has to survive
      # that and still list the hosts.
      machine.succeed("mkdir -p /tmp/repo/modules/hosts/test-host && touch /tmp/repo/flake.nix")
      machine.succeed("echo '{\"system\": [\"nix\"], \"users\": {}}' > /tmp/repo/modules/hosts/test-host/features.json")
      machine.succeed("systemd-run --unit=switchboard-web switchboard --flake /tmp/repo web --no-open")
      machine.wait_for_open_port(7391)

      # The page carries this run's token, and the API answers only to it.
      token = machine.succeed("curl -fsS http://127.0.0.1:7391/ | grep -o 'content=\"[0-9a-f]*\"' | cut -d'\"' -f2").strip()
      assert len(token) == 32, f"the page carries no token: {token!r}"
      machine.succeed(f"curl -fsS -H 'X-Switchboard-Token: {token}' http://127.0.0.1:7391/api/state | grep -q testHost")
      machine.fail("curl -fsS http://127.0.0.1:7391/api/state")
      # Loopback is every account's: another user does not even get the page
      # (the server runs as root here, the request comes from `nobody`).
      machine.fail("runuser -u nobody -- curl -fsS http://127.0.0.1:7391/")
      # A forged Host header — what a DNS-rebinding page would send — is refused.
      machine.fail(f"curl -fsS -H 'Host: evil.example' -H 'X-Switchboard-Token: {token}' http://127.0.0.1:7391/api/state")
      # The page has no login, so the server never binds off loopback.
      machine.fail("switchboard --flake /tmp/repo web --no-open --addr 0.0.0.0:7392")
    '';
  };
}
