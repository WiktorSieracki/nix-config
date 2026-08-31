{lib, ...}: {
  options.flake.niriBinds = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri keybindings contributed by feature modules, as functions {pkgs, lib} -> binds attrset";
  };

  options.flake.niriSpawnAtStartup = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Commands niri spawns at session start, contributed by feature modules as functions {pkgs, lib} -> string (a single executable path; wrap in writeShellScript when arguments are needed). Appended to settings.spawn-at-startup.";
  };

  options.flake.niriWindowRules = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri window-rules contributed by feature modules, as functions {pkgs, lib} -> window-rule attrset. Collected (prepended) into the window-rules list.";
  };

  options.flake.niriOutputs = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Niri output (monitor) definitions contributed by host modules, merged into settings.outputs (connector name -> definition). Keeps host-specific monitor layouts out of the shared niri feature; niri ignores entries whose connector is not present.";
  };

  options.flake.niriWorkspaces = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    description = "Named niri workspaces contributed by feature modules, merged into settings.workspaces (name -> definition).";
  };
}
