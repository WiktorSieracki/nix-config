{
  lib,
  config,
  inputs,
  ...
}: let
  mkNixos = system: cls: name:
    lib.nixosSystem {
      inherit system;
      modules = [
        config.flake.modules.nixos.${cls}
        config.flake.modules.nixos."hosts/${name}"
        {
          networking.hostName = lib.mkDefault name;
          nixpkgs.hostPlatform = lib.mkDefault system;
          # The commit a generation was built from, shown by `nixos-version
          # --configuration-revision` and `nixos-rebuild list-generations`, so
          # "which commit was the last good one" has an answer. A build from a
          # dirty tree records the `-dirty` rev.
          system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;
          # This value determines the NixOS release from which the default
          # settings for stateful data, like file locations and database versions
          # on your system were taken. It‘s perfectly fine and recommended to leave
          # this value at the release version of the first install of this system.
          # Before changing this value read the documentation for this option
          # (e.g. man configuration.nix or on https://search.nixos.org/options?&show=system.stateVersion&from=0&size=50&sort=relevance&type=packages&query=stateVersion).
          system.stateVersion = "24.11";
        }
      ];
    };

  linux = mkNixos "x86_64-linux" "nixos";
in {
  # `flake.lib` is an undeclared freeform flake output, so flake-parts can't
  # merge contributions from more than one module. Keep ALL of `flake.lib` here
  # (sole writer); other harness helpers live under their own attr (e.g.
  # feature-tests.nix → `flake.featureTestLib.mkFeatureTest`) and are only *read* elsewhere.
  flake.lib.mkSystems = {
    inherit linux;
  };

  # mkHostUser — the single account factory. Creates the Unix user
  # from its `flake.meta.users` entry and wires its home-manager evaluation:
  # the HM modules it is handed plus a foundation that injects `userMeta`
  # (identity + `login`) via `_module.args`, so features never hardcode a
  # login. Shared by loadHost (real hosts) and mkFeatureTest (the neutral `tester`
  # test account), so the feature tests exercise the same wiring the hosts use.
  flake.lib.mkHostUser = {
    login,
    userMeta,
    hmModules ? [],
    # A passwordSecret can only be honored where the sops module exists; on
    # secret-less hosts (vm/iso) the account is created without it and the
    # host sets its own initialPassword. loadHost derives this from the spec.
    sopsAvailable ? true,
  }: let
    hasSopsPassword = (userMeta ? passwordSecret) && sopsAvailable;
  in
    {
      pkgs,
      config,
      ...
    }:
      {
        users.users.${login} =
          {
            isNormalUser = true;
            # GECOS is what the SDDM greeter labels the account with, so it takes
            # displayName when the identity distinguishes the two (fullName alone
            # made the two accounts of one person indistinguishable at login).
            description = userMeta.displayName or userMeta.fullName or login;
            extraGroups = userMeta.groups or [];
          }
          // lib.optionalAttrs (userMeta ? shell) {
            shell = pkgs.${userMeta.shell};
          }
          // lib.optionalAttrs (userMeta ? authorizedKeys) {
            openssh.authorizedKeys.keys = userMeta.authorizedKeys;
          }
          // lib.optionalAttrs hasSopsPassword {
            hashedPasswordFile = config.sops.secrets.${userMeta.passwordSecret}.path;
          };

        home-manager.users.${login}.imports =
          hmModules
          ++ [
            {
              _module.args.userMeta = userMeta // {inherit login;};
              home.username = login;
              home.homeDirectory = "/home/${login}";
              home.stateVersion = "24.11";
              programs.home-manager.enable = true;
            }
          ];
      }
      # The password hash must be decrypted before user creation (sysusers runs
      # early), hence neededForUsers. Guarded so hosts/feature tests without the sops
      # module never even mention the option.
      // lib.optionalAttrs hasSopsPassword {
        sops.secrets.${userMeta.passwordSecret}.neededForUsers = true;
      };

  # loadHost — assembles a host from its spec:
  #   { users = [ "<login>" ... ];   # the accounts the machine has
  #     features = [ ... ]; }        # everything it enables — its features.json
  # One list, on purpose. A feature's NixOS part configures the machine and its
  # home-manager part, when it has one, attaches to every account — which half
  # a feature brings is the feature's business, not something to sort by hand
  # into "system" and "user" lists. Accounts are created via mkHostUser, with
  # identity from flake.meta.users. Validation hard-fails (no auto-pulling):
  # every name must be a feature, and a feature's `requires` must be on the
  # list too.
  flake.lib.loadHost = config: spec:
    assert builtins.isAttrs spec; let
      meta = config.flake.featureMeta or {};
      usersMeta = config.flake.meta.users or {};
      # A name listed twice is the same module twice — harmless here, an
      # "option defined multiple times" further down. Keep the first.
      features = lib.unique (spec.features or []);
      logins = spec.users or [];

      reqs = m: (meta.${m} or {}).requires or [];
      missing = m: lib.filter (d: !(builtins.elem d features)) (reqs m);

      # Mutually exclusive features (e.g. two skill sets that both ship a `tdd`
      # skill, so both would define the same home.file). Without this the clash
      # surfaces as an opaque home-manager "conflicting definition values"
      # error naming a file; this names both features.
      conflicts = m: (meta.${m} or {}).conflicts or [];
      # Declaring the conflict on either side is enough — the pair is rendered
      # name-sorted so a mutual declaration doesn't report it twice.
      clashes = lib.unique (lib.concatMap (
          m:
            map (c: lib.concatStringsSep " and " (lib.sort (a: b: a < b) ["'${m}'" "'${c}'"]))
            (lib.filter (c: c != m && builtins.elem c features) (conflicts m))
        )
        features);

      # A features.json name is real iff it has a NixOS part, a home-manager
      # part, or an explicit featureMeta (the last covers module-less features
      # like `personal-snippets` that only add global niriBinds). Without this,
      # `... or {}` below silently turns a typo or stale name into a no-op,
      # undermining "features.json is the source of truth".
      isFeature = m:
        (config.flake.modules.nixos ? ${m})
        || (config.flake.modules.homeManager ? ${m})
        || (meta ? ${m});

      errs =
        map (m: "  feature '${m}' is not a known feature (no NixOS/home-manager module and no featureMeta)")
        (lib.filter (m: !(isFeature m)) features)
        ++ lib.concatMap (
          m:
            map (d: "  feature '${m}' requires '${d}' but the host does not enable it")
            (missing m)
        )
        features
        ++ map (p: "  features ${p} conflict — a host may enable only one")
        clashes
        ++ map (u: "  host declares user '${u}' but flake.meta.users has no entry for it")
        (lib.filter (u: !(usersMeta ? ${u})) logins)
        # With no account, a home-manager part would attach to nobody and the
        # feature would silently do half its job.
        ++ map (m: "  feature '${m}' has a home-manager part but the host has no account for it to attach to")
        (lib.optionals (logins == []) (lib.filter (m: config.flake.modules.homeManager ? ${m}) features));

      userModules =
        map (
          login:
            config.flake.lib.mkHostUser {
              inherit login;
              userMeta = usersMeta.${login};
              sopsAvailable = builtins.elem "sops" features;
              hmModules =
                # The always-on HM floor (cursor/ghostty theme, …) plus the
                # home-manager part of every feature that has one.
                [config.flake.modules.homeManager.homeManager]
                ++ map (m: config.flake.modules.homeManager.${m} or {}) features;
            }
        )
        logins;
    in
      lib.throwIf (errs != []) ''
        host spec validation failed — fix features.json / flake.meta.users:
        ${lib.concatStringsSep "\n" errs}
      ''
      ((map (m: config.flake.modules.nixos.${m} or {}) features)
        ++ [
          {
            imports = [inputs.home-manager.nixosModules.home-manager];

            home-manager = {
              # No leading dot: home-manager inserts its own, so ".bak" would
              # produce "settings.json..bak". `overwriteBackup` keeps a stale
              # backup from failing the next activation on a file collision.
              backupFileExtension = "hm-bak";
              overwriteBackup = true;
              useGlobalPkgs = true;
              useUserPackages = true;
            };

            # Lets a feature's NixOS part act per account (git renders one sops
            # email template per login, syncthing lets each linger): the
            # accounts of this host, each with the features it has — which is
            # all of them. The same shape the feature tests inject for `tester`.
            _module.args.hostUsers = lib.genAttrs logins (_: features);
          }
        ]
        ++ userModules);
}
