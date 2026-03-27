{
  flake.modules.nixos.nixos = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      tree
      treecat
      tealdeer
      bruno-cli
      neovim
    ];
  };
}
