{
  flake.modules.nixos.obsidian = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      obsidian
    ];
  };

  flake.featureMeta.obsidian = {
    requires = [];
    kind = "gui";
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem
  # pkgs (parts.nix), so no extra module is needed.
  flake.featureTests.obsidian = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v obsidian")
    '';
  };
}
