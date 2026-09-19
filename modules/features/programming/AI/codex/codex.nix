{inputs, ...}: {
  flake.modules.nixos.codex = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    ];
  };

  flake.featureMeta.codex = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: codex → "codex".
    provides.systemBins = ["codex"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.codex = {};
}
