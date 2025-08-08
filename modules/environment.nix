{
  config,
  lib,
  pkgs,
  hostname ? "unknown",
  ...
}:

let
  isWSL = hostname == "desktop-wsl" || builtins.pathExists "/proc/sys/fs/binfmt_misc/WSLInterop";
  isNixOS = hostname == "laptop-nixos" || builtins.pathExists "/etc/NIXOS";
in
{
  # Export environment detection for use in other modules
  config = {
    home.sessionVariables = {
      IS_WSL = if isWSL then "1" else "0";
      IS_NIXOS = if isNixOS then "1" else "0";
      CURRENT_HOSTNAME = hostname;
    };
  };
}
