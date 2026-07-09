{
  config,
  lib,
  inputs,
  ...
}: {
  # Declare the custom freeform flake outputs so multiple feature modules can
  # contribute to them (otherwise flake-parts rejects >1 definition as
  # "defined multiple times" — same reason niri-binds.nix declares niriBinds).
  options.flake = {
    featureMeta = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Per-feature metadata: { <feature> = { requires; kind; }; }.";
    };
    probaTests = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Per-feature Próba specs: { <feature> = { testScript; extraNixosModules?; extraHmModules?; }; }.";
    };
    proba = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Próba harness helpers (e.g. mkProba).";
    };
  };

  # Having an `options` block forces all settings under an explicit `config`.
  config = {
  # mkProba — builds a Tier-1 Próba: a headless `nixosTest` whose VM is the
  # `core` floor (flake.modules.nixos.nixos) + the feature under test + the
  # transitive closure of its `requires` (read from flake.featureMeta). The VM
  # contains *nothing else*, so a passing Próba proves the feature is
  # self-sufficient given its declared deps. See docs/adr/0002.
  #
  # Feature files DON'T call this directly — they register a Próba spec under
  # `flake.probaTests.<name>` (a multi-writer freeform attr, like niriBinds) and
  # the central perSystem below turns each into `checks.feature-<name>`. This
  # keeps the test set introspectable so `feature-coverage` can audit it.
  #
  # Lives under `flake.proba` (not `flake.lib`) because `flake.lib` is an
  # undeclared freeform output that flake-parts won't merge across modules.
  flake.proba.mkProba = {
    pkgs,
    feature,
    testScript,
    requires ? (config.flake.featureMeta.${feature}.requires or []),
    # `kind` is accepted for symmetry / future rigor defaults; unused for now.
    kind ? (config.flake.featureMeta.${feature}.kind or "config"),
    extraNixosModules ? [],
    # Extra home-manager modules merged into the test user's HM — used by Próby
    # to stub secret-backed config (e.g. point SOPS at a fixture, ADR 0002 (b)).
    extraHmModules ? [],
  }: let
    meta = config.flake.featureMeta or {};

    # Transitive closure of `requires` over featureMeta (feature itself excluded).
    closure =
      map (i: i.key) (builtins.genericClosure {
        startSet = map (m: {key = m;}) requires;
        operator = item: map (d: {key = d;}) ((meta.${item.key} or {}).requires or []);
      });

    enabled = [feature] ++ closure;
    nixosModules = map (m: config.flake.modules.nixos.${m} or {}) enabled;
    hmModules = map (m: config.flake.modules.homeManager.${m} or {}) enabled;

    # A feature with a home-manager part needs an account to attach to. The
    # Próba uses the neutral `proba` test identity, created by the SAME
    # mkHostUser factory the hosts use (ADR 0004) — so a hardcoded real login
    # inside a feature fails its Próba, and the wiring itself gets exercised.
    # Pure-system Próby (no HM part in the closure) skip it for a leaner VM.
    hasHm = lib.any (m: (config.flake.modules.homeManager or {}) ? ${m}) enabled;
    hmWiring = lib.optionals hasHm [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          backupFileExtension = ".bak";
          useGlobalPkgs = true;
          useUserPackages = true;
        };
      }
      (config.flake.lib.mkHostUser {
        login = "proba";
        userMeta = {
          fullName = "Proba Testowa";
          groups = [];
        };
        hmModules = hmModules ++ extraHmModules;
      })
    ];
  in
    pkgs.testers.runNixOSTest {
      name = "feature-${feature}";
      nodes.machine = {...}: {
        imports =
          [
            config.flake.modules.nixos.nixos # Core floor
            # Mirror the loader's injection: features' NixOS parts may ask
            # which accounts enable them (e.g. git). In the Próba that's the
            # test account with the whole closure. (A module-fn default like
            # `hostUsers ? {}` does NOT kick in — the module system always
            # queries _module.args for non-standard args.)
            {_module.args.hostUsers = lib.optionalAttrs hasHm {proba = enabled;};}
          ]
          ++ nixosModules
          ++ extraNixosModules
          ++ hmWiring;
      };
      inherit testScript;
    };

  perSystem = {pkgs, ...}: let
    meta = config.flake.featureMeta or {};
    tests = config.flake.probaTests or {};

    # The feature universe: every nixos OR home-manager module name, minus the
    # always-on bases (`nixos` = Core, `homeManager`) and host pseudo-modules.
    isPseudo = n: n == "nixos" || n == "homeManager" || lib.hasPrefix "hosts/" n;
    featureNames =
      lib.filter (n: !(isPseudo n))
      (lib.unique (
        lib.attrNames (config.flake.modules.nixos or {})
        ++ lib.attrNames (config.flake.modules.homeManager or {})
      ));

    # ── feature-coverage (D) ─────────────────────────────────────────────────
    # Consistency (always on): a feature with `featureMeta` must have a Próba and
    # vice-versa, and meta/tests must name real features. This needs no central
    # list, so parallel rollout doesn't fight over a shared file — each feature
    # is self-consistent on its own. Completeness (every feature has meta+Próba)
    # is gated by `enforceAll`; flip it to true once the rollout (G) is done.
    metaNames = lib.attrNames meta;
    testNames = lib.attrNames tests;
    # Rollout (G) complete — every feature must now have featureMeta + a Próba.
    enforceAll = true;

    problems =
      map (f: "  feature '${f}' has featureMeta but no Próba (probaTests entry)") (lib.subtractLists testNames metaNames)
      ++ map (f: "  feature '${f}' has a Próba but no featureMeta") (lib.subtractLists metaNames testNames)
      ++ map (n: "  featureMeta.'${n}' does not name a real feature") (lib.filter (n: !(builtins.elem n featureNames)) metaNames)
      ++ map (n: "  probaTests.'${n}' does not name a real feature") (lib.filter (n: !(builtins.elem n featureNames)) testNames)
      ++ lib.optionals enforceAll (map (f: "  feature '${f}' has no featureMeta/Próba — every feature must have one") (lib.subtractLists metaNames featureNames));

    # Generate one check per registered Próba: checks.feature-<name>.
    featureChecks =
      lib.mapAttrs' (
        name: spec:
          lib.nameValuePair "feature-${name}"
          (config.flake.proba.mkProba (spec // {inherit pkgs; feature = name;}))
      )
      tests;
  in {
    checks =
      featureChecks
      // {
        feature-coverage =
          lib.throwIf (problems != []) ''
            feature-coverage failed:
            ${lib.concatStringsSep "\n" problems}
          ''
          (pkgs.runCommand "feature-coverage-ok" {} "echo 'coverage ok' > $out");

        # Harness self-test: proves the Core floor boots and that mkProba +
        # flake.checks plumbing works, independent of any real feature.
        core-smoke = config.flake.proba.mkProba {
          inherit pkgs;
          feature = "core-smoke"; # not a real module → resolves to {}
          requires = [];
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.succeed("command -v tree")
            machine.fail("systemctl cat display-manager.service")
          '';
        };

        # Mechanism Próba (ADR 0004): the per-user wiring itself. Two test
        # accounts built by the same mkHostUser factory the hosts use; asserts
        # what used to live in the dissolved `work-user` feature — isolation is
        # a property of the loader, not of any feature: HM parts attach only to
        # the listing account, shell/privileges come only from the identity
        # (meta.users), homes are mutually unreadable (default homeMode 700).
        host-users = pkgs.testers.runNixOSTest {
          name = "host-users-mechanism";
          nodes.machine = {...}: {
            imports = [
              config.flake.modules.nixos.nixos # Core floor
              config.flake.modules.nixos.fish
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  backupFileExtension = ".bak";
                  useGlobalPkgs = true;
                  useUserPackages = true;
                };
              }
              (config.flake.lib.mkHostUser {
                login = "proba";
                userMeta = {
                  fullName = "Proba Testowa";
                  groups = ["wheel"];
                  shell = "fish";
                };
                hmModules = [
                  config.flake.modules.homeManager.fish
                  config.flake.modules.homeManager.wallpapers
                ];
              })
              (config.flake.lib.mkHostUser {
                login = "proba2";
                userMeta = {
                  fullName = "Proba Druga";
                  groups = [];
                };
                hmModules = [];
              })
            ];
          };
          testScript = ''
            machine.wait_for_unit("multi-user.target")
            machine.wait_for_unit("home-manager-proba.service")
            machine.wait_for_unit("home-manager-proba2.service")

            # Accounts exist, identity (GECOS) comes from userMeta.
            machine.succeed("getent passwd proba | grep -q 'Proba Testowa'")
            machine.succeed("getent passwd proba2 | grep -q 'Proba Druga'")

            # Login shell comes from userMeta.shell, not from the fish feature.
            machine.succeed("getent passwd proba | cut -d: -f7 | grep -q fish")
            machine.fail("getent passwd proba2 | cut -d: -f7 | grep -q fish")

            # HM parts attach ONLY to the account that lists the feature.
            machine.succeed("test -f /home/proba/Pictures/Wallpapers/wallhaven_p92g1m.jpg")
            machine.fail("test -e /home/proba2/Pictures")
            machine.succeed("su - proba -c 'command -v direnv'")
            machine.fail("su - proba2 -c 'command -v direnv'")

            # Privilege comes only from the identity's groups.
            machine.succeed("id -nG proba | grep -qw wheel")
            machine.fail("id -nG proba2 | grep -qw wheel")
            machine.fail("su - proba2 -c 'sudo -n true'")

            # Homes mutually unreadable (NixOS default homeMode 700).
            machine.fail("su - proba2 -c 'ls /home/proba'")
            machine.fail("su - proba -c 'ls /home/proba2'")
          '';
        };
      };
  };
  };
}
