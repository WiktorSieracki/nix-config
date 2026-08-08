{inputs, ...}: {
  flake.modules.nixos.pi = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    ];
  };

  flake.featureMeta.pi = {
    requires = [];
    kind = "cli";
    # Binary name from meta.mainProgram: pi → "pi".
    provides.systemBins = ["pi"];
  };

  # feature test: fully covered by `provides` — no extra script needed.
  flake.featureTests.pi = {};
}
