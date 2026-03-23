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
}
