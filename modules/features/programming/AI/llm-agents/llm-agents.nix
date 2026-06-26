{inputs, ...}: {
  flake.modules.nixos.llm-agents = {pkgs, ...}: {
    environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      claude-code
      opencode
      omp
      # pi
      # gemini-cli
      # qwen-code
      # ... other tools
    ];
  };

  flake.featureMeta.llm-agents = {
    requires = [];
    kind = "cli";
  };

  # Próba: assert the three active AI agent binaries are on PATH.
  # Binary names from package meta.mainProgram: claude-code→"claude", opencode→"opencode", omp→"omp".
  flake.probaTests.llm-agents = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v claude")
      machine.succeed("command -v opencode")
      machine.succeed("command -v omp")
    '';
  };
}
