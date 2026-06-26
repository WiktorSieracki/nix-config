{
  flake.modules.nixos.bruno = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bruno
      bruno-cli
    ];
  };

  flake.featureMeta.bruno = {
    requires = [];
    kind = "gui";
  };

  flake.probaTests.bruno = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v bruno")
    '';
  };
}
