{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-addons = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    homeConfigurations = {
      "wiktor@desktop-wsl" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home/desktop-wsl/home.nix
        ];
        extraSpecialArgs = {
          inherit inputs;
          hostname = "desktop-wsl";
        };
      };
    };
    nixosConfigurations."wiktor@laptop-nixos" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/laptop
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = {
            inherit inputs;
            hostname = "laptop-nixos";
          };
        }
      ];
    };
    nixosConfigurations."wiktor@desktop-nixos" = nixpkgs.lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/desktop
        home-manager.nixosModules.home-manager
        {
          home-manager.extraSpecialArgs = {
            inherit inputs;
            hostname = "desktop-nixos";
          };
        }
      ];
    };
  };
}
