{
  flake.modules.nixos.typst = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      typst
      typstyle
      typst-live
      font-awesome
    ];
  };
}
