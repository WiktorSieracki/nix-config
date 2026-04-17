{
  flake.modules.nixos.python = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      python314
      uv
      ruff
    ];
  };
}
