{inputs, ...}: {
  flake.modules.nixos.llm-agents = {pkgs, ...}: {
    environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
      claude-code
      opencode
      pi
      # gemini-cli
      # qwen-code
      # ... other tools
    ];
  };
}
