{
  flake.modules.homeManager.nix = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;

    home.packages = with pkgs; [
      alejandra
      nixd
      nix-search-cli
      nixfmt
    ];
  };
}
