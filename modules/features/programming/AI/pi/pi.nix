{inputs, ...}: {
  flake.modules.nixos.pi = {pkgs, ...}: {
    environment.systemPackages = [
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
    ];
  };

  flake.featureMeta.pi = {
    requires = [];
    kind = "cli";
  };

  # Próba: binary name from meta.mainProgram: pi → "pi".
  flake.probaTests.pi = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v pi")
    '';
  };
}
