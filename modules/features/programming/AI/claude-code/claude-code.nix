{inputs, ...}: {
  flake.modules.nixos.claude-code = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
    ];
  };

  flake.featureMeta.claude-code = {
    requires = [];
    kind = "cli";
  };

  # feature test: binary name from meta.mainProgram: claude-code → "claude".
  flake.featureTests.claude-code = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v claude")
    '';
  };
}
