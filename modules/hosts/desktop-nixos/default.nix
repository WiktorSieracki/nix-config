{
  self,
  inputs,
  ...
}: {
  flake.nixosConfigurations.desktopNixos = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.desktopNixosConfiguration
    ];
  };

  flake.homeConfigurations.wiktor = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    modules = [
      self.homeModules.wiktor
    ];
  };
  
}
