{
  lib,
  config,
  ...
}: {
  # Build handles for the real machines' system closures.
  #
  # CI (`.github/workflows/hosts.yaml`) builds these on every push to `main`
  # and the Cachix action uploads the result to `wiktor-nixos`. That is what
  # makes "install a minimal ISO, then pull the config off the internet" cheap:
  # `nixos-install --flake github:...#desktopNixos` substitutes the closure --
  # including this repo's own packages (agent-of-empires, custom-scripts, ...)
  # -- instead of building it on a freshly-installed machine.
  #
  # It doubles as the cheapest answer to "do both machines still build?", which
  # nothing checked before: `nix build .#desktopNixos-system`.
  #
  # Not registered under `checks`: `nix flake check` would then build two full
  # host closures on every run, which is not what that command is for here.
  perSystem = {system, ...}: {
    packages = lib.optionalAttrs (system == "x86_64-linux") {
      desktopNixos-system = config.flake.nixosConfigurations.desktopNixos.config.system.build.toplevel;
      laptopNixos-system = config.flake.nixosConfigurations.laptopNixos.config.system.build.toplevel;
    };
  };
}
