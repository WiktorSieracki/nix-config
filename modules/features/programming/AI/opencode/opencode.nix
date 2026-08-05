{inputs, ...}: {
  flake.modules.nixos.opencode = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    ];
  };

  flake.featureMeta.opencode = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: opencode → "opencode".
    provides.systemBins = ["opencode"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.opencode = {};
}
