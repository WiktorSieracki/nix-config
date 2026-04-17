{
  flake.modules.nixos.affine = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      affine
    ];
  };
}
