{lib, ...}: {
  options.flake.niriBinds = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri keybindings contributed by feature modules, as functions {pkgs, lib} -> binds attrset";
  };
}
