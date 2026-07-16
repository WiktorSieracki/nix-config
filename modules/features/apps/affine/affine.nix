{
  flake.modules.nixos.affine = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      affine
    ];
  };

  flake.featureMeta.affine = {
    requires = ["desktop"];
    kind = "gui";
  };

  flake.featureTests.affine = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v affine")
    '';
  };
}
