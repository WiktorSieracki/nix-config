{
  flake.modules.nixos.pre-commit = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      pre-commit
    ];
  };
}
