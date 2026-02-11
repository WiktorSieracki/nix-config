{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    alacritty
    xwayland-satellite
    fuzzel
  ];

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  home-manager.users.wiktor = {
    home.file.".config/niri/config.kdl".source = ./config.kdl;
  };
}
