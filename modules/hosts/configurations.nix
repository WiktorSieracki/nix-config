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
          home-manager.users.wiktor.imports = [
            config.flake.modules.homeManager.homeManager
            (config.flake.modules.homeManager."hosts/${name}" or {})
          ];

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

  flake.lib.loadNixosAndHmModuleForUser = config: modules:
      assert builtins.isAttrs config;
      assert builtins.isList modules; let
        # featureMeta-driven dependency check: every `requires` of an enabled
        # feature must itself be enabled on the host. We hard-fail instead of
        # auto-pulling, so a host's module list is always the complete truth
        # about its dependency graph (for humans and AI alike). See docs/adr/0002.
        meta = config.flake.featureMeta or {};
        errs =
          lib.concatMap (
            m:
              map (d: "  feature '${m}' requires '${d}' but the host does not enable it")
              (lib.filter (d: !(builtins.elem d modules)) ((meta.${m} or {}).requires or []))
          )
          modules;
      in
        lib.throwIf (errs != []) ''
          featureMeta validation failed — add the missing feature(s) to the host's module list:
          ${lib.concatStringsSep "\n" errs}
        ''
        ((map (module: config.flake.modules.nixos.${module} or {}) modules)
          ++ [
            {
              imports = [inputs.home-manager.nixosModules.home-manager];

              home-manager.users.wiktor.imports =
                map (
                  module: config.flake.modules.homeManager.${module} or {}
                )
                modules;
            }
          ]);
}
