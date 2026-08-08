{inputs, ...}: {
  flake.modules.nixos.claude-code = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];
  };

  flake.featureMeta.claude-code = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: claude-code → "claude".
    provides.systemBins = ["claude"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.claude-code = {};
}
