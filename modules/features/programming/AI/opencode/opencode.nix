{inputs, ...}: {
  flake.modules.nixos.opencode = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
    ];
  };

  flake.featureMeta.opencode = {
    requires = [];
    kind = "cli";
  };

  # feature test: binary name from meta.mainProgram: opencode → "opencode".
  flake.featureTests.opencode = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v opencode")
    '';
  };
}
