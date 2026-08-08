{
  flake.modules.nixos.nodejs = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      nodejs
      pnpm
    ];
  };

  # Pure system feature: Node.js and pnpm on PATH.
  flake.featureMeta.nodejs = {
    requires = [];
    kind = "cli";
    provides.systemBins = ["node" "pnpm"];
  };

  # feature test: `provides` covers PATH; the version calls are the runtime smoke.
  flake.featureTests.nodejs = {
    testScript = ''
      machine.succeed("node --version")
      machine.succeed("pnpm --version")
    '';
  };
}
