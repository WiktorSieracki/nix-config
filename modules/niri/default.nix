{pkgs, ...}: {
  home.packages = with pkgs; [
    alacritty
    xwayland-satellite
    fuzzel
  ];

  home.file.".config/niri/config.kdl".source = ./config.kdl;
}
