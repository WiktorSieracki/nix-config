{
  flake.modules.nixos.pre-commit = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      pre-commit
    ];
  };

  # Pure system feature: pre-commit tool on PATH.
  flake.featureMeta.pre-commit = {
    requires = [];
    kind = "cli";
  };

  # Próba: pre-commit is on PATH.
  flake.probaTests.pre-commit = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("pre-commit --version")
    '';
  };
}
