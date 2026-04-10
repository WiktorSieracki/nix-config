{
  flake.modules.nixos.nodejs = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      nodejs
      pnpm
    ];
  };
}
