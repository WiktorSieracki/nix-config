{lib, ...}: {
  options.flake.niriBinds = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri keybindings contributed by feature modules, as functions {pkgs, lib} -> binds attrset";
  };

  options.flake.niriWindowRules = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri window-rules contributed by feature modules, as functions {pkgs, lib} -> window-rule attrset. Collected (prepended) into the window-rules list.";
  };

  options.flake.niriWorkspaces = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Named niri workspaces contributed by feature modules, merged into settings.workspaces (name -> definition).";
  };
}
