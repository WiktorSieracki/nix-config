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
    # aoe's Structured (ACP) view spawns a per-agent adapter binary off $PATH —
    # for Claude that's `claude-agent-acp`. aoe ships no adapters itself.
    requires = ["claude-agent-acp"];
    kind = "cli";
  };

  # feature test: aoe-with-web exposes mainProgram = "aoe".
  # tmux is a standard binary; assert both are on PATH.
  flake.featureTests.agent-of-empires = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v aoe")
      machine.succeed("command -v tmux")

      # `aoe acp doctor` is aoe's own view of which agents it can actually
      # drive — it marks each configured agent [OK] or [!!] by probing $PATH.
      # Assert Claude is usable, i.e. the requires above is really wired.
      # Its exit code is deliberately ignored: doctor exits 2 on anything less
      # than a full house, and this VM is *meant* to be partial — the adapters
      # for codex/gemini/opencode/... are not this feature's business, and no
      # `nodejs` (aoe's bundled JS agent wants it; the hosts supply it).
      _, doctor = machine.execute("aoe acp doctor")
      assert "[OK] claude " in doctor, f"claude agent not usable by aoe:\n{doctor}"
    '';
  };
}
