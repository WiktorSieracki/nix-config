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
    provides.systemBins = ["pre-commit"];
  };

  # feature test: `provides` covers PATH; the version call is the runtime smoke.
  flake.featureTests.pre-commit = {
    testScript = ''
      machine.succeed("pre-commit --version")
    '';
  };
}
