{
  description = "Home Manager configuration of wiktor";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations = {
        # Desktop WSL configuration
        "wiktor@desktop-wsl" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./hosts/desktop-wsl/home.nix ];
          extraSpecialArgs = {
            hostname = "desktop-wsl";
          };
        };

        # Laptop NixOS configuration
        "wiktor@laptop-nixos" = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            ./hosts/laptop-nixos/home.nix
            ./hosts/laptop-nixos/configuration.nix
            ./hosts/laptop-nixos/hardware-configuration.nix
          ];
          extraSpecialArgs = {
            hostname = "laptop-nixos";
          };
        };

      };
    };
}
