{
  flake.modules.nixos.bruno = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      bruno
      bruno-cli
    ];
  };
}
