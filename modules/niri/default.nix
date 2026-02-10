{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.niri.nixosModules.niri];

  programs.niri.enable = true;

  home.packages = with pkgs; [
    alacritty
    xwayland-satellite
    fuzzel
  ];

  home.sessionVariables.NIXOS_OZONE_WL = "1";

  home.file.".config/niri/config.kdl".source = ./config.kdl;
}
