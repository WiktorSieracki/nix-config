{
  flake.modules.nixos.nix = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;
    nix.settings.experimental-features = ["nix-command" "flakes"];

    environment.systemPackages = with pkgs; [
      alejandra
      nixd
      nix-search-cli
      nixfmt
      nh
    ];

    environment.sessionVariables = {
      NH_FLAKE = "/home/wiktor/.config/nix-config";
      FLAKE = "/home/wiktor/.config/nix-config";
    };
  };
}
