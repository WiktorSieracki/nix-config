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
  };

  # feature test: node and pnpm are on PATH.
  flake.featureTests.nodejs = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("node --version")
      machine.succeed("pnpm --version")
    '';
  };
}
