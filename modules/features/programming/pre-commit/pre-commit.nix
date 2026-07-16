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

  # feature test: pre-commit is on PATH.
  flake.featureTests.pre-commit = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("pre-commit --version")
    '';
  };
}
