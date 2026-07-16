{
  flake.modules.nixos.python = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      python314
      uv
      ruff
    ];
  };

  # Pure system feature: Python 3.14, uv, and ruff on PATH.
  flake.featureMeta.python = {
    requires = [];
    kind = "cli";
  };

  # Próba: the three CLIs are on PATH and respond to version flags.
  flake.featureTests.python = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("python3 --version")
      machine.succeed("uv --version")
      machine.succeed("ruff --version")
    '';
  };
}
