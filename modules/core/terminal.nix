{config, ...}: {
  flake.niriBinds.terminal = {pkgs, lib}: {
    "Mod+Return".spawn-sh = "${lib.getExe pkgs.${config.flake.meta.programs.terminal}} --gtk-single-instance=true";
  };

  flake.modules.nixos.nixos = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.${config.flake.meta.programs.terminal}
    ];

    environment.variables = {
      TERM = "${config.flake.meta.programs.terminal}";
    };
  };
}
