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

  # Próba: nixpkgs.config.allowUnfree is already true in the outer perSystem
  # pkgs (parts.nix), so no extra module is needed.
  flake.probaTests.obsidian = {
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("command -v obsidian")
    '';
  };
}
