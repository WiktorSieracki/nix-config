{
  flake.modules.nixos.obsidian = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      obsidian
    ];
  };

  flake.featureMeta.obsidian = {
    requires = ["desktop"];
    kind = "gui";
    provides.systemBins = ["obsidian"];
  };

  # feature test: nixpkgs.config.allowUnfree is already true in the outer perSystem
  # pkgs (parts.nix), so no extra module is needed.
  flake.featureTests.obsidian = {};
}
