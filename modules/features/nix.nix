{
  flake.modules.nixos.nix = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nix.settings.substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    nix.settings.trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];

    environment.systemPackages = with pkgs; [
      alejandra
      nixd
      nix-search-cli
      nixfmt
      nh
      comma
      manix
    ];

    environment.sessionVariables = {
      NH_FLAKE = "/home/wiktor/.config/nix-config";
      FLAKE = "/home/wiktor/.config/nix-config";
    };
  };
}
