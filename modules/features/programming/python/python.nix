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
    provides.systemBins = ["python3" "uv" "ruff"];
  };

  # feature test: `provides` covers PATH; the version calls are the runtime smoke.
  flake.featureTests.python = {
    testScript = ''
      machine.succeed("python3 --version")
      machine.succeed("uv --version")
      machine.succeed("ruff --version")
    '';
  };
}
