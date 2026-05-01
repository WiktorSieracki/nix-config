{config, ...}: {
  flake.modules.nixos.nixos = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.${config.flake.meta.programs.terminal}
    ];

    environment.variables = {
      TERM = "${config.flake.meta.programs.terminal}";
    };
  };
}
