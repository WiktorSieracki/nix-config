{
  flake.modules.nixos.teams-for-linux = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      teams-for-linux
    ];
  };
}
