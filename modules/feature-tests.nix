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
      description = "Per-feature metadata: { <feature> = { requires; kind; provides?; }; }.";
    };
    featureTests = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Per-feature feature-test specs: { <feature> = { testScript?; extraNixosModules?; extraHmModules?; }; }.";
    };
    featureTestLib = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Feature-test harness helpers (e.g. mkFeatureTest).";
    };
  };

  # Having an `options` block forces all settings under an explicit `config`.
  config = {
    # The `provides` vocabulary — the declarative half of a feature test. Each key
    # maps a thing the feature puts on the system to the assertion that proves it.
    # `feature-coverage` reads the same table to reject unknown keys, so adding a
    # kind of evidence means adding it here and nowhere else.
    flake.featureTestLib.providesKeys = [
      "systemBins" # binaries in the system profile        → command -v
      "userBins" #   binaries in the tester's HM profile   → su - tester -c 'command -v'
      "units" #      systemd system units                  → wait_for_unit
      "ports" #      TCP ports something listens on        → wait_for_open_port
      "files" #      paths that must exist (root's view)   → test -e
      "userFiles" #  paths in the tester's home            → su - tester -c 'test -e'
    ];

    # mkFeatureTest — builds a Tier-1 feature test: a headless `nixosTest` whose VM
    # is the `core` floor (flake.modules.nixos.nixos) + the feature under test + the
    # transitive closure of its `requires` (read from flake.featureMeta). The VM
    # contains *nothing else*, so a passing feature test proves the feature is
    # self-sufficient given its declared deps. See docs/adr/0002.
    #
    # Feature files DON'T call this directly — they register a feature-test spec
    # under `flake.featureTests.<name>` (a multi-writer freeform attr, like
    # niriBinds) and the central perSystem below turns each into
    # `checks.feature-<name>`. This keeps the test set introspectable so
    # `feature-coverage` can audit it.
    #
    # Lives under `flake.featureTestLib` (not `flake.lib`) because `flake.lib` is an
    # undeclared freeform output that flake-parts won't merge across modules.
    flake.featureTestLib.mkFeatureTest = {
      pkgs,
      feature,
      # Optional: a feature whose `provides` says everything needs no script.
      testScript ? "",
      requires ? (config.flake.featureMeta.${feature}.requires or []),
      # `kind` sets the rigor level (ADR 0002): it decides which `provides` a
      # feature must declare — enforced in feature-coverage below, not here.
      kind ? (config.flake.featureMeta.${feature}.kind or "config"),
      provides ? (config.flake.featureMeta.${feature}.provides or {}),
      extraNixosModules ? [],
      # Extra home-manager modules merged into the test user's HM — used by feature
      # tests to stub secret-backed config (e.g. point SOPS at a fixture, ADR 0002 (b)).
      extraHmModules ? [],
    }: let
      meta = config.flake.featureMeta or {};

      # Transitive closure of `requires` over featureMeta (feature itself excluded).
      closure = map (i: i.key) (builtins.genericClosure {
        startSet = map (m: {key = m;}) requires;
        operator = item: map (d: {key = d;}) ((meta.${item.key} or {}).requires or []);
      });

      enabled = [feature] ++ closure;
      nixosModules = map (m: config.flake.modules.nixos.${m} or {}) enabled;
      hmModules = map (m: config.flake.modules.homeManager.${m} or {}) enabled;

      # A feature with a home-manager part needs an account to attach to. The
      # feature test uses the neutral `tester` test identity, created by the SAME
      # mkHostUser factory the hosts use (ADR 0004) — so a hardcoded real login
      # inside a feature fails its feature test, and the wiring itself gets exercised.
      # Pure-system feature tests (no HM part in the closure) skip it for a leaner VM.
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
          login = "tester";
          userMeta = {
            fullName = "Test User";
            groups = [];
          };
          hmModules = hmModules ++ extraHmModules;
        })
      ];

      # ── generated assertions ─────────────────────────────────────────────────
      # The lines every feature test used to hand-copy, derived once from `kind` +
      # `provides`. Order: boot floor → HM activation → units/ports → binaries →
      # files, then the feature's own `testScript` for behaviour a declaration
      # can't express. `hasHm` above already knows whether a `tester` account
      # exists, so the HM wait is never guessed at.
      declared = key: provides.${key} or [];
      line = s: s + "\n";
      generated =
        line ''machine.wait_for_unit("multi-user.target")''
        + lib.optionalString hasHm (line ''machine.wait_for_unit("home-manager-tester.service")'')
        + lib.concatMapStrings (u: line ''machine.wait_for_unit("${u}")'') (declared "units")
        + lib.concatMapStrings (n: line "machine.wait_for_open_port(${toString n})") (declared "ports")
        + lib.concatMapStrings (b: line ''machine.succeed("command -v ${b}")'') (declared "systemBins")
        + lib.concatMapStrings (b: line ''machine.succeed("su - tester -c 'command -v ${b}'")'') (declared "userBins")
        + lib.concatMapStrings (f: line ''machine.succeed("test -e ${f}")'') (declared "files")
        + lib.concatMapStrings (f: line ''machine.succeed("su - tester -c 'test -e ${f}'")'') (declared "userFiles");
    in
      pkgs.testers.runNixOSTest {
        name = "feature-${feature}";
        nodes.machine = {...}: {
          imports =
            [
              config.flake.modules.nixos.nixos # Core floor
              # Mirror the loader's injection: features' NixOS parts may ask
              # which accounts enable them (e.g. git). In the feature test that's
              # the test account with the whole closure. (A module-fn default like
              # `hostUsers ? {}` does NOT kick in — the module system always
              # queries _module.args for non-standard args.)
              {_module.args.hostUsers = lib.optionalAttrs hasHm {tester = enabled;};}
            ]
            ++ nixosModules
            ++ extraNixosModules
            ++ hmWiring;
        };
        testScript = generated + testScript;
      };

    perSystem = {pkgs, ...}: let
      meta = config.flake.featureMeta or {};
      tests = config.flake.featureTests or {};

      # The feature universe: every nixos OR home-manager module name, PLUS any
      # name with an explicit `featureMeta` (so a module-less feature that only
      # contributes global niriBinds — e.g. `personal-snippets` — still counts and
      # gets coverage-gated), minus the always-on bases (`nixos` = Core,
      # `homeManager`) and host pseudo-modules.
      isPseudo = n: n == "nixos" || n == "homeManager" || lib.hasPrefix "hosts/" n;
      featureNames =
        lib.filter (n: !(isPseudo n))
        (lib.unique (
          lib.attrNames (config.flake.modules.nixos or {})
          ++ lib.attrNames (config.flake.modules.homeManager or {})
          ++ lib.attrNames meta
        ));

      # Transitive `requires` closure of a feature over featureMeta (feature
      # excluded), mirroring mkFeatureTest's closure.
      reqClosure = f:
        map (i: i.key) (builtins.genericClosure {
          startSet = map (m: {key = m;}) ((meta.${f} or {}).requires or []);
          operator = item: map (d: {key = d;}) ((meta.${item.key} or {}).requires or []);
        });
      # The desktop stack itself (`desktop` + everything it requires, i.e. niri) is
      # exempt from the gui⇒desktop rule below — those features ARE the session.
      desktopStack = ["desktop"] ++ reqClosure "desktop";

      # ── feature-coverage (D) ─────────────────────────────────────────────────
      # Consistency (always on): a feature with `featureMeta` must have a feature
      # test and vice-versa, and meta/tests must name real features. This needs no
      # central list, so parallel rollout doesn't fight over a shared file — each
      # feature is self-consistent on its own. Completeness (every feature has
      # meta+test) is gated by `enforceAll`; flip it to true once the rollout (G)
      # is done.
      metaNames = lib.attrNames meta;
      testNames = lib.attrNames tests;
      # Rollout (G) complete — every feature must now have featureMeta + a feature test.
      enforceAll = true;

      # ── kind ⇒ provides (ADR 0002's rigor level, enforced) ───────────────────
      # `kind` says what a feature *is*; `provides` says what it puts on the
      # system. This pairing is what stops a test from existing while asserting
      # nothing. `runtimeUntestable` features are exempt — by definition their
      # runtime can't be reached from a VM.
      providesKeys = config.flake.featureTestLib.providesKeys;
      provOf = f: (meta.${f} or {}).provides or {};
      declares = f: keys: lib.any (k: (provOf f).${k} or [] != []) keys;
      testable = f: !((meta.${f} or {}).runtimeUntestable or false);
      kindOf = f: (meta.${f} or {}).kind or null;

      # A `su - tester` assertion needs the tester account, which mkFeatureTest
      # only creates when the closure carries a home-manager part.
      closureHasHm = f:
        lib.any (m: (config.flake.modules.homeManager or {}) ? ${m})
        ([f] ++ reqClosure f);

      rigorProblems =
        # unknown `provides` key — typo guard, applies to every feature
        lib.concatMap (
          f:
            map (k: "  featureMeta.${f}.provides.${k} is not a known key — expected one of: ${lib.concatStringsSep ", " providesKeys}")
            (lib.subtractLists providesKeys (lib.attrNames (provOf f)))
        )
        metaNames
        # cli/gui must put a binary somewhere
        ++ map (f: "  ${kindOf f} feature '${f}' declares no binary — add featureMeta.${f}.provides.systemBins or .userBins (or mark it runtimeUntestable)")
        (lib.filter (f: testable f && !(declares f ["systemBins" "userBins"]))
          (lib.filter (f: builtins.elem (kindOf f) ["cli" "gui"]) metaNames))
        # service must name a unit
        ++ map (f: "  service feature '${f}' declares no unit — add featureMeta.${f}.provides.units (or mark it runtimeUntestable)")
        (lib.filter (f: testable f && (provOf f).units or [] == [])
          (lib.filter (f: kindOf f == "service") metaNames))
        # a tester-scoped assertion with no tester account could never run
        ++ map (f: "  feature '${f}' declares provides.userBins/userFiles but neither it nor its `requires` closure has a home-manager part — there is no `tester` account to assert against")
        (lib.filter (f: declares f ["userBins" "userFiles"] && !(closureHasHm f)) metaNames);

      problems =
        map (f: "  feature '${f}' has featureMeta but no feature test (featureTests entry)") (lib.subtractLists testNames metaNames)
        ++ map (f: "  feature '${f}' has a feature test but no featureMeta") (lib.subtractLists metaNames testNames)
        ++ map (n: "  featureMeta.'${n}' does not name a real feature") (lib.filter (n: !(builtins.elem n featureNames)) metaNames)
        ++ map (n: "  featureTests.'${n}' does not name a real feature") (lib.filter (n: !(builtins.elem n featureNames)) testNames)
        ++ lib.optionals enforceAll (map (f: "  feature '${f}' has no featureMeta/feature test — every feature must have one") (lib.subtractLists metaNames featureNames))
        # gui⇒desktop (CONTEXT.md, ADR 0002): a `kind = "gui"` feature must reach
        # `desktop` through its `requires`, so its feature test boots the real
        # graphical session instead of silently passing on `core` alone. The
        # desktop stack itself (niri) is exempt.
        ++ map (f: "  gui feature '${f}' must `requires` \"desktop\" (directly or transitively) — see CONTEXT.md / ADR 0002")
        (lib.filter
          (f: !(builtins.elem f desktopStack) && !(builtins.elem "desktop" (reqClosure f)))
          (lib.filter (f: (meta.${f}.kind or null) == "gui") metaNames))
        ++ rigorProblems;

      # Generate one check per registered feature test: checks.feature-<name>.
      featureChecks =
        lib.mapAttrs' (
          name: spec:
            lib.nameValuePair "feature-${name}"
            (config.flake.featureTestLib.mkFeatureTest (spec
              // {
                inherit pkgs;
                feature = name;
              }))
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

          # Harness self-test: proves the Core floor boots and that mkFeatureTest +
          # flake.checks plumbing works, independent of any real feature.
          core-smoke = config.flake.featureTestLib.mkFeatureTest {
            inherit pkgs;
            feature = "core-smoke"; # not a real module → resolves to {}
            requires = [];
            testScript = ''
              machine.succeed("command -v tree")
              machine.fail("systemctl cat display-manager.service")
            '';
          };

          # Mechanism feature test (ADR 0004): the per-user wiring itself. Two test
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
                  login = "tester";
                  userMeta = {
                    fullName = "Test User";
                    groups = ["wheel"];
                    shell = "fish";
                  };
                  hmModules = [
                    config.flake.modules.homeManager.fish
                    config.flake.modules.homeManager.wallpapers
                  ];
                })
                (config.flake.lib.mkHostUser {
                  login = "tester2";
                  userMeta = {
                    fullName = "Second Test User";
                    groups = [];
                  };
                  hmModules = [];
                })
              ];
            };
            testScript = ''
              machine.wait_for_unit("multi-user.target")
              machine.wait_for_unit("home-manager-tester.service")
              machine.wait_for_unit("home-manager-tester2.service")

              # Accounts exist, identity (GECOS) comes from userMeta.
              machine.succeed("getent passwd tester | grep -q 'Test User'")
              machine.succeed("getent passwd tester2 | grep -q 'Second Test User'")

              # Login shell comes from userMeta.shell, not from the fish feature.
              machine.succeed("getent passwd tester | cut -d: -f7 | grep -q fish")
              machine.fail("getent passwd tester2 | cut -d: -f7 | grep -q fish")

              # HM parts attach ONLY to the account that lists the feature.
              machine.succeed("test -f /home/tester/Pictures/Wallpapers/wallhaven_p92g1m.jpg")
              machine.fail("test -e /home/tester2/Pictures")
              machine.succeed("su - tester -c 'command -v direnv'")
              machine.fail("su - tester2 -c 'command -v direnv'")

              # Privilege comes only from the identity's groups.
              machine.succeed("id -nG tester | grep -qw wheel")
              machine.fail("id -nG tester2 | grep -qw wheel")
              machine.fail("su - tester2 -c 'sudo -n true'")

              # Homes mutually unreadable (NixOS default homeMode 700).
              machine.fail("su - tester2 -c 'ls /home/tester'")
              machine.fail("su - tester -c 'ls /home/tester2'")
            '';
          };
        };
    };
  };
}
