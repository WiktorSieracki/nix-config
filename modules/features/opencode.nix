{
  flake.modules.nixos.opencode = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      opencode
    ];
  };
}
