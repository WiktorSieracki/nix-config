{inputs, ...}: {
  imports = [inputs.niri.nixosModules.niri];
  programs.niri.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";
}
