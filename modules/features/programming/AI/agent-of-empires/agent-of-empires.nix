{inputs, ...}: {
  flake.modules.nixos.agent-of-empires = {pkgs, ...}: {
    # Agent of Empires (aoe): session manager for AI coding agents.
    # `aoe-with-web` includes the web dashboard / local network serving;
    # swap for `default` for the CLI/TUI-only build.
    environment.systemPackages = [
      inputs.agent-of-empires.packages.${pkgs.stdenv.hostPlatform.system}.aoe-with-web
      pkgs.tmux # aoe shells out to tmux for session management
    ];
  };

  flake.featureMeta.agent-of-empires = {
    requires = [];
    kind = "cli";
  };

  # Próba: aoe-with-web exposes mainProgram = "aoe".
  # tmux is a standard binary; assert both are on PATH.
  flake.probaTests.agent-of-empires = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v aoe")
      machine.succeed("command -v tmux")
    '';
  };
}
