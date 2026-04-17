{
  flake.modules.nixos.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      alacritty
    ];
  };
}
