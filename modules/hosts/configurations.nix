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
  linux-arm = mkNixos "aarch64-linux" "nixos";

  wsl = mkNixos "x86_64-linux" "wsl";
in {
  # `flake.lib` is an undeclared freeform flake output, so flake-parts can't
  # merge contributions from more than one module. Keep ALL of `flake.lib` here
  # (sole writer); other harness helpers live under their own attr (e.g.
  # proba.nix → `flake.proba.mkProba`) and are only *read* elsewhere.
  flake.lib.mkSystems = {
    inherit
      linux
      linux-arm
      wsl
      ;
  };

  # mkHostUser — the single account factory (ADR 0004). Creates the Unix user
  # from its `flake.meta.users` entry and wires its home-manager evaluation:
  # the per-user HM modules plus a foundation that injects `userMeta`
  # (identity + `login`) via `_module.args`, so user features never hardcode a
  # login. Shared by loadHost (real hosts) and mkProba (the neutral `proba`
  # test account), so the Próby exercise the same wiring the hosts use.
  flake.lib.mkHostUser = {
    login,
    userMeta,
    hmModules ? [],
  }: {
    pkgs,
    config,
    ...
  }:
    {
      users.users.${login} =
        {
          isNormalUser = true;
          description = userMeta.fullName or login;
          extraGroups = userMeta.groups or [];
        }
        // lib.optionalAttrs (userMeta ? shell) {
          shell = pkgs.${userMeta.shell};
        }
        // lib.optionalAttrs (userMeta ? authorizedKeys) {
          openssh.authorizedKeys.keys = userMeta.authorizedKeys;
        }
        // lib.optionalAttrs (userMeta ? passwordSecret) {
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
    # early), hence neededForUsers. Guarded so hosts/Próby without the sops
    # module never even mention the option.
    // lib.optionalAttrs (userMeta ? passwordSecret) {
      sops.secrets.${userMeta.passwordSecret}.neededForUsers = true;
    };

  # loadHost — assembles a host from its features.json spec (ADR 0003/0004):
  #   { system = [ ... ];               # machine features (hardware, services)
  #     users.<login> = [ ... ]; }      # per-account user features
  # NixOS parts of every mentioned feature merge globally (that's how NixOS
  # works); home-manager parts attach ONLY to the accounts that list them.
  # Accounts themselves are created from the `users` keys via mkHostUser, with
  # identity from flake.meta.users. Validation hard-fails (no auto-pulling,
  # ADR 0002): a feature's `requires` must be satisfied by `system` plus the
  # same user's own list; a feature with a home-manager part may not sit in
  # `system` (its HM half would silently attach to nobody).
  flake.lib.loadHost = config: spec:
    assert builtins.isAttrs spec; let
      meta = config.flake.featureMeta or {};
      usersMeta = config.flake.meta.users or {};
      system = spec.system or [];
      users = spec.users or {};
      logins = builtins.attrNames users;

      reqs = m: (meta.${m} or {}).requires or [];
      missing = enabled: m: lib.filter (d: !(builtins.elem d (system ++ enabled))) (reqs m);

      errs =
        lib.concatMap (
          m:
            map (d: "  system feature '${m}' requires '${d}' but `system` does not enable it")
            (missing [] m)
        )
        system
        ++ lib.concatMap (
          u:
            lib.concatMap (
              m:
                map (d: "  feature '${m}' (user '${u}') requires '${d}' but neither `system` nor `users.${u}` enables it")
                (missing users.${u} m)
            )
            users.${u}
        )
        logins
        ++ map (u: "  host declares user '${u}' but flake.meta.users has no entry for it")
        (lib.filter (u: !(usersMeta ? ${u})) logins)
        ++ map (m: "  feature '${m}' has a home-manager part but is enabled in `system` — move it to a user list, or its HM half attaches to nobody")
        (lib.filter (m: config.flake.modules.homeManager ? ${m}) system);

      allFeatures = lib.unique (system ++ lib.concatLists (lib.attrValues users));

      userModules =
        map (
          login:
            config.flake.lib.mkHostUser {
              inherit login;
              userMeta = usersMeta.${login};
              hmModules =
                # The always-on HM floor (cursor/ghostty theme, …) plus the
                # user's own features.
                [config.flake.modules.homeManager.homeManager]
                ++ map (m: config.flake.modules.homeManager.${m} or {}) users.${login};
            }
        )
        logins;
    in
      lib.throwIf (errs != []) ''
        host spec validation failed — fix features.json / flake.meta.users:
        ${lib.concatStringsSep "\n" errs}
      ''
      ((map (m: config.flake.modules.nixos.${m} or {}) allFeatures)
        ++ [
          {
            imports = [inputs.home-manager.nixosModules.home-manager];

            home-manager = {
              backupFileExtension = ".bak";
              useGlobalPkgs = true;
              useUserPackages = true;
            };

            # Lets a feature's NixOS part know which accounts enable it (e.g.
            # git renders one sops email template per user that lists it).
            _module.args.hostUsers = users;
          }
        ]
        ++ userModules);
}
