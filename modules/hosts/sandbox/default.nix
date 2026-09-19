{
  lib,
  config,
  ...
}: let
  meta = config.flake.featureMeta;
  tests = config.flake.featureTests;

  # Transitive `requires` closure, identical to the one mkFeatureTest computes —
  # the live sandbox must contain exactly what the headless feature test
  # contains, or "works in the sandbox" would stop meaning "works in Tier 1".
  reqClosure = f:
    map (i: i.key) (builtins.genericClosure {
      startSet = map (m: {key = m;}) ((meta.${f} or {}).requires or []);
      operator = item: map (d: {key = d;}) ((meta.${item.key} or {}).requires or []);
    });

  hmFeature = m: config.flake.modules.homeManager ? ${m};

  # The sandbox's own infrastructure, present in every variant including the
  # base. The desktop is not a convenience here: the probe the agent drives the
  # guest with (`niri msg`, grim, wtype) is a set of Wayland clients, so without
  # a running session there is nothing to look at and nothing to click.
  # Consequence to keep in mind: a `cli` feature meets a desktop here that its
  # Tier-1 test deliberately withholds — isolation from the desktop stays Tier
  # 1's job, not the sandbox's.
  infraFeatures = ["desktop" "niri"];

  # `runtimeUntestable` means the runtime cannot be reached from a VM at all
  # (no GPU, no tablet, no real SOPS key). Booting a sandbox for one could only
  # ever produce a false "it works", so no config is generated and the runner
  # refuses the name. Features that merely *depend* on such a feature are fine:
  # they carry their own Tier-1 stubs, reused below.
  testable = f: !((meta.${f} or {}).runtimeUntestable or false);
  sandboxFeatures = lib.filter testable (lib.attrNames meta);

  # A host spec in the features.json shape, so the sandbox goes through the very
  # same loadHost validation as desktopNixos/laptopNixos (requires closed,
  # conflicts, no HM-carrying feature in `system`). A feature with a
  # home-manager part must sit in the account's list — loadHost loads the NixOS
  # halves of user features too, so nothing is lost by putting it there.
  mkSpec = features: let
    all = lib.unique (infraFeatures ++ lib.concatMap (f: [f] ++ reqClosure f) features);
  in {
    system = lib.filter (m: !(hmFeature m)) all;
    users.tester = lib.filter hmFeature all;
  };

  # Tier-1's escape hatches, reused verbatim: a secret-backed feature (git, …)
  # blanks its SOPS wiring in `flake.featureTests.<f>` so the VM can boot without
  # the real key. Taking the same stubs here is what keeps `sandbox-git`
  # evaluable — and keeps the sandbox from inventing a second, drifting notion
  # of "how this feature is faked".
  extrasOf = features: let
    specs = lib.filter (s: s != null) (map (f: tests.${f} or null) features);
  in {
    nixos = lib.concatMap (s: s.extraNixosModules or []) specs;
    hm = lib.concatMap (s: s.extraHmModules or []) specs;
  };

  mkSandbox = features: let
    extras = extrasOf features;
  in
    lib.nixosSystem {
      system = "x86_64-linux";
      modules =
        [
          config.flake.modules.nixos.nixos # Core floor
          config.flake.modules.nixos."hosts/sandbox"
          {home-manager.users.tester.imports = extras.hm;}
        ]
        ++ config.flake.lib.loadHost config (mkSpec features)
        ++ extras.nixos;
    };
in {
  # The shared half of every sandbox VM. Lives under the `hosts/` prefix on
  # purpose: feature-coverage treats every other name in `flake.modules.nixos`
  # as a feature owing featureMeta + a feature test (modules/feature-tests.nix),
  # and the sandbox is infrastructure, not a feature.
  flake.modules.nixos."hosts/sandbox" = {
    pkgs,
    lib,
    modulesPath,
    ...
  }: let
    # A command arriving over ssh lands in an empty environment, while every
    # tool the agent needs (niri msg, grim, wtype, ydotool) talks to a socket it
    # can only find through the session's env. Rather than have the runner guess
    # those paths from the host, the guest resolves them itself — one place that
    # knows how a niri session names its sockets.
    sandboxEnv = pkgs.writeShellApplication {
      name = "sandbox-env";
      runtimeInputs = [pkgs.coreutils];
      text = ''
        XDG_RUNTIME_DIR="/run/user/$(id -u)"
        export XDG_RUNTIME_DIR

        # Globs rather than `ls |grep`: the lock files sit next to the sockets
        # and only a `-S` test tells them apart.
        WAYLAND_DISPLAY=""
        for sock in "$XDG_RUNTIME_DIR"/wayland-[0-9]*; do
          [ -S "$sock" ] || continue
          WAYLAND_DISPLAY="$(basename "$sock")"
          break
        done
        export WAYLAND_DISPLAY

        NIRI_SOCKET=""
        for sock in "$XDG_RUNTIME_DIR"/niri.*.sock; do
          [ -S "$sock" ] || continue
          NIRI_SOCKET="$sock"
          break
        done
        export NIRI_SOCKET

        export YDOTOOL_SOCKET=/run/ydotoold/socket

        if [ -z "$WAYLAND_DISPLAY" ]; then
          echo "sandbox-env: no wayland socket in $XDG_RUNTIME_DIR — is the session up?" >&2
        fi

        exec "$@"
      '';
    };
  in {
    # The QEMU VM module is imported *directly* rather than through
    # `virtualisation.vmVariant`, so this host's own `system.build.toplevel` is
    # the VM — root filesystem, port forward and all. That is what makes
    # `nixos-rebuild --target-host` possible: with the vmVariant indirection the
    # plain toplevel has no root filesystem, fails to evaluate, and the feature
    # could never be installed into the running machine. It also removes a whole
    # class of confusion — what we deploy is exactly what is running.
    imports = [(modulesPath + "/virtualisation/qemu-vm.nix")];

    # The VM boots its kernel directly (-kernel/-initrd), so there is no ESP and
    # nothing for a bootloader to install into. Core enables GRUB, which makes
    # every `deploy` die at the final step with "will not proceed with
    # blocklists" — after the closure has already been copied, so the machine
    # is left half-switched.
    boot.loader.grub.enable = lib.mkForce false;

    networking.hostName = lib.mkDefault "sandbox";
    nixpkgs.hostPlatform = "x86_64-linux";
    system.stateVersion = "24.11";

    # Throwaway machine reachable only through QEMU's user-net forward on
    # 127.0.0.1 — root over ssh is how `nixos-rebuild --target-host` installs
    # the feature under test into the running VM. mkForce because the
    # `ssh-server` feature (which may itself be the feature under test) sets
    # PermitRootLogin = "no".
    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = lib.mkForce "yes";
        PasswordAuthentication = lib.mkForce false;
      };
    };
    users.users.root.openssh.authorizedKeys.keys =
      config.flake.meta.users.tester.authorizedKeys;

    # Straight into the tester's niri session — the agent's checks run against a
    # real graphical session, not a login screen.
    services.displayManager.autoLogin = {
      enable = true;
      user = "tester";
    };
    users.users.tester.initialPassword = "sandbox";
    security.sudo.wheelNeedsPassword = false;

    # Real hosts inherit allowUnfree from the `nix` feature, which a sandbox for
    # some *other* feature has no reason to enable — without this, testing e.g.
    # a browser feature dies on an unfree license instead of booting.
    nixpkgs.config.allowUnfree = true;

    # Same reason as the `vm` host: ghostty (and anything else on OpenGL) gets
    # no working GL context through nested virgl and renders nothing.
    environment.sessionVariables.LIBGL_ALWAYS_SOFTWARE = "1";

    # The NixOS manual is rebuilt whenever anything in this repo changes, and
    # it is the single slowest thing standing between an edit and a booted
    # sandbox. Nobody reads it inside a throwaway VM.
    documentation.nixos.enable = false;

    # The probe — the agent's eyes and hands inside the guest.
    programs.ydotool.enable = true;
    environment.systemPackages = [
      pkgs.grim # screenshots straight from the compositor
      pkgs.jq # `niri msg -j` is the guest's window tree
      pkgs.wtype # text and keysyms into the session
      sandboxEnv
    ];

    virtualisation = {
      # Deliberately modest: this VM runs *next to* a desktop session and an
      # editor, not instead of them. 3G is enough for niri plus one application
      # under software GL; the runner additionally caps the whole QEMU process
      # with MemoryMax so a runaway guest cannot reach the host's other work.
      memorySize = 3072;
      cores = 2;
      diskSize = 8192;
      graphics = true;

      # Mandatory, not a tweak. The guest reaches /nix/store over virtiofs
      # (vhost-user-fs), and that protocol can only work if QEMU's guest RAM is
      # a shareable memfd — which nixpkgs leaves off by default. Without it the
      # three virtiofs daemons connect, immediately fail their handshake
      # ("Error starting vhost: 5"), and the guest never gets a store to boot
      # from: the VM shows no console, answers no ssh, and nothing says why.
      qemu.enableSharedMemory = true;
      forwardPorts = [
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
      # Hardware only. How the VM is *displayed* is the runner's business and
      # stays in its QEMU_OPTS, so this config keeps evaluating (and could still
      # boot) on a machine with no Wayland session. `-name` is what the niri
      # window rule on the host matches to park the window on the right monitor.
      qemu.options = [
        "-name nix-sandbox"
        "-vga none"
        "-device virtio-vga-gl"
      ];
    };
  };

  flake.nixosConfigurations =
    {
      # The red state: everything the sandbox needs to be driven, and no feature
      # under test. A check that passes here is measuring nothing.
      sandbox-base = mkSandbox [];
    }
    // lib.listToAttrs (map
      (f: lib.nameValuePair "sandbox-${f}" (mkSandbox [f]))
      sandboxFeatures);

  # Guard against generator rot: force the part of every sandbox variant that
  # this file is actually responsible for — the generated spec and loadHost's
  # validation of it (requires closed, conflicts, no HM-carrying feature in
  # `system`). That is where a new or edited feature breaks the sandbox, and it
  # costs one cheap eval per feature.
  #
  # It deliberately stops short of evaluating the 55 complete NixOS systems:
  # doing that in a single `nix flake check` process needs many gigabytes of
  # RAM, which on this machine means the desktop's own processes start dying.
  # The full system eval still happens — once, for one feature — when the agent
  # actually runs `sandbox up`.
  perSystem = {pkgs, ...}: {
    checks.sandbox-eval = let
      validated = map (
        f: builtins.length (config.flake.lib.loadHost config (mkSpec [f]))
      ) sandboxFeatures;
      base = builtins.length (config.flake.lib.loadHost config (mkSpec []));
    in
      builtins.seq base (builtins.deepSeq validated
        (pkgs.runCommand "sandbox-eval-ok" {} "echo 'sandbox specs validate' > $out"));
  };
}
