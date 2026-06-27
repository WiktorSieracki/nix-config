{config, ...}: let
  terminal = config.flake.meta.programs.terminal;
  mkToggle = pkgs:
    pkgs.writeShellApplication {
      name = "quickterm-toggle";
      runtimeInputs = [pkgs.jq pkgs.${terminal}];
      text = builtins.readFile ./quickterm-toggle.sh;
    };
in {
  # Quake-style scratchpad terminal for niri (Mod+grave). niri can't natively
  # toggle a quick terminal (it lacks the global-shortcut portal ghostty's own
  # quick-terminal needs), so this is a script-driven scratchpad instead: a
  # floating ghostty tagged app-id "quickterm", stashed on the "scratch"
  # workspace when hidden so a running command (e.g. `nh os switch`) survives.
  flake.niriBinds.quickTerminal = {
    pkgs,
    lib,
  }: {
    "Mod+Shift+Return".spawn-sh = lib.getExe (mkToggle pkgs);
  };

  flake.niriWindowRules.quickTerminal = _: {
    matches = [{app-id = "^com\\.quickterm\\.Scratchpad$";}];
    open-floating = true;
  };

  flake.niriWorkspaces.scratch = _: {};
}
